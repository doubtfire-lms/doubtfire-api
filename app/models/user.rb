require 'bcrypt'
require 'authorisation_helpers'

# Modify the string class to fix the titilize issue where
# names could be stripped on import. Eg a blank name entered as "-"
#
# encoding: utf-8
class String
  def titleize()
    result = ActiveSupport::Inflector.titleize(self)
    return self if self.present? && result.blank?

    return result
  end
end

class User < ApplicationRecord
  include AuthenticationHelpers

  include UserTiiModule

  ###
  # Authentication
  ###

  # User authentication config
  if AuthenticationHelpers.aaf_auth?
    #
    # Decodes a JWS against the JWT secret, returning JWT data or nil if no data
    # could be decoded
    #
    def self.decode_jws(jws)
      JSON::JWT.decode(jws.to_s, Doubtfire::Application.credentials.secret_key_aaf)
    rescue
      nil
    end

    #
    # Validates a JSON web Signature against assertion rules. Returns false if
    # it could not be verified.
    #
    def valid_jwt?(jws)
      # 1. The signed JWT matches the JWT key
      jwt = User.decode_jws(jws)
      return false if jwt.nil?

      # 2. The `aud` claim matches the application URL
      aud_ok = jwt['aud'] == Doubtfire::Application.config.aaf[:audience_url]
      # 3. The `iss` claim has the correct issuer URL
      iss_ok = jwt['iss'] == Doubtfire::Application.config.aaf[:issuer_url]
      # 4. The time MUST >= nbf time and < exp claim
      time_ok = Time.zone.now >= Time.zone.at(jwt['nbf']) &&
                Time.zone.now <  Time.zone.at(jwt['exp'])
      # Assert all
      aud_ok && iss_ok && time_ok
    end
  else
    devise_keys = %i(registerable recoverable rememberable trackable validatable)
    strategy = AuthenticationHelpers.ldap_auth? ? :ldap_authenticatable : :database_authenticatable
    devise strategy, *devise_keys
  end

  #
  # We incorporate password details for local dev server - needed to keep devise happy
  #
  def password
    'password'
  end

  def password_confirmation
    'password'
  end

  def password=(value)
    self.encrypted_password = BCrypt::Password.create(value)
  end

  #
  # Authenticates a user against a piece of data
  #
  def authenticate?(data)
    if aaf_auth?
      valid_jwt?(data)
    elsif ldap_auth?
      valid_ldap_authentication?(data)
    else
      valid_password?(data)
    end
  end

  #
  # Force-generates a new authentication token, regardless of whether or not
  # it is actually expired
  #
  def generate_authentication_token!(remember: false, expiry: Time.zone.now + 2.hours, token_type: :general)
    # Ensure this user is saved... so it has an id
    self.save unless self.persisted?
    AuthToken.generate(self, remember, expiry, token_type)
  end

  #
  # Generate an authentication token that will expire in 30 seconds
  #
  def generate_temporary_authentication_token!
    generate_authentication_token!(expiry: Time.zone.now + 30.seconds, token_type: :login)
  end

  #
  # Generate an authentication token for scorm asset retrieval
  #
  def generate_scorm_authentication_token!
    generate_authentication_token!(token_type: :scorm)
  end

  #
  # Returns whether the authentication token has expired
  #
  def authentication_token_expired?
    auth_token_expiry.nil? || auth_token_expiry <= Time.zone.now
  end

  #
  # Returns authentication of the user
  #
  def token_for_text?(a_token, token_type)
    tokens_to_check = self.auth_tokens
    tokens_to_check = tokens_to_check.where(token_type: token_type) if token_type.present?

    tokens_to_check.each do |token|
      if a_token == token.authentication_token
        return token
      end
    end
    return nil
  end

  ###
  # Schema
  ###

  # Model associations
  belongs_to  :role, optional: false # Foreign Key
  has_many    :unit_roles, dependent: :destroy, inverse_of: :user
  has_many    :projects, dependent: :restrict_with_exception, inverse_of: :user
  has_many    :auth_tokens, dependent: :destroy, inverse_of: :user
  has_one     :webcal, dependent: :destroy, inverse_of: :user

  # Model validations/constraints
  validates :first_name,  presence: true
  validates :last_name,   presence: true
  validates :role_id,     presence: true
  validates :username,    presence: true, uniqueness: { case_sensitive: false }
  validates :email,       presence: true, uniqueness: { case_sensitive: false }, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }
  validates :student_id,  uniqueness: true, allow_nil: true
  validate :can_change_to_role?, if: :will_save_change_to_role_id?

  # Queries
  scope :tutors,    -> { joins(:role).where('roles.id = :tutor_role or roles.id = :convenor_role or roles.id = :admin_role or roles.id = :auditor_role', tutor_role: Role.tutor_id, convenor_role: Role.convenor_id, admin_role: Role.admin_id, auditor_role: Role.auditor_id) }
  scope :convenors, -> { joins(:role).where('roles.id = :convenor_role or roles.id = :admin_role or roles.id = :auditor_role', convenor_role: Role.convenor_id, admin_role: Role.admin_id, auditor_role: Role.auditor_id) }
  scope :admins,    -> { joins(:role).where('roles.id = :admin_role or roles.id = :auditor_role', admin_role: Role.admin_id, auditor_role: Role.auditor_id) }
  scope :auditors,  -> { joins(:role).where('roles.id = :auditor_role', auditor_role: Role.auditor_id) }

  def self.teaching(unit)
    User.joins(:unit_roles).where('unit_roles.unit_id = :unit_id and ( unit_roles.role_id = :tutor_role_id or unit_roles.role_id = :convenor_role_id) ', unit_id: unit.id, tutor_role_id: Role.tutor_id, convenor_role_id: Role.convenor_id)
  end

  # def username=(name)
  #   # strip S or s from start of ids in the form S1234567 or S123456X
  #   truncate_s_match = (name =~ /^[Ss]\d{6,10}([Xx]|\d)$/)
  #   name[0] = '' if !truncate_s_match.nil? && truncate_s_match.zero?
  #   self[:username] = name.downcase
  # end

  def can_change_to_role?
    new_role = self.role

    fail_if_in_unit_role = [Role.tutor, Role.convenor] if new_role == Role.student
    fail_if_in_unit_role = [Role.convenor] if new_role == Role.tutor
    fail_if_in_unit_role = [] if new_role == Role.admin || new_role == Role.convenor || new_role == Role.auditor

    for check_role in fail_if_in_unit_role do
      if unit_roles.where('role_id = :role_id', role_id: check_role.id).count > 0
        errors.add :role, "cannot be changed to #{new_role.name} because the user has a #{check_role.name} role in a unit"
      end
    end
  end

  def has_student_capability?
    true
  end

  def has_tutor_capability?
    role_id == Role.tutor_id || has_convenor_capability?
  end

  def has_convenor_capability?
    role_id == Role.convenor_id || has_admin_capability?
  end

  def has_admin_capability?
    role_id == Role.admin_id
  end

  def has_auditor_capability?
    role_id == Role.auditor_id
  end

  def self.get_change_role_perm_fn
    lambda do |role, perm_hash, other|
      from_role = other[0]
      to_role = other[1]

      (chg_roles = perm_hash[:change_role]) && # get the change role hash - ensure it exists
        (role_hash = chg_roles[role]) && # get the role from...
        (from_role_hash = role_hash[from_role]) && # get the role to from within the role from
        from_role_hash[to_role] # the permissions allowed
    end
  end

  #
  # Permissions around user data
  #
  def self.permissions
    # Change role permissons:
    #   who can change a Doubtfire user's role?
    change_role_permissions = {
      # The current_user's role is an Administrator
      admin: {
        # User being changed is an admin?
        #   An admin current_user can demote them to either a student, tutor or convenor
        admin: {     student: [:demote_user],
                     tutor: [:demote_user],
                     convenor: [:demote_user],
                     auditor: [:demote_user] },
        # User being changed is an auditor?
        #   An admin current_user can demote them to either a student, tutor or convenor
        #   An admin current_user can promote them to an admin
        auditor: {   student: [:promote_user],
                     tutor: [:promote_user],
                     convenor: [:promote_user],
                     admin: [:promote_user] },
        # User being changed is a convenor?
        #   An admin current_user can demote them to student or tutor or auditor
        #   An admin current_user can promote them to an admin
        convenor: {  student: [:demote_user],
                     tutor: [:demote_user],
                     admin: [:promote_user],
                     auditor: [:demote_user] },
        # User being changed is a tutor?
        #   An admin current_user can demote them to a student or auditor
        #   An admin current_user can promote them to a convenor, admin or auditor
        tutor: {     student: [:demote_user],
                     convenor: [:promote_user],
                     admin: [:promote_user],
                     auditor: [:demote_user] },
        # User being assigned is a student?
        #   An admin current_user can promote them to a tutor, convenor, admin or auditor
        student: {   tutor: [:promote_user],
                     convenor: [:promote_user],
                     admin: [:promote_user],
                     auditor: [:promote_user] },
        # User being assigned has no role?
        #   An admin current_user can create user to any role
        nil: {       student: [:create_user],
                     tutor: [:create_user],
                     convenor: [:create_user],
                     admin: [:create_user],
                     auditor: [:create_user] }
      },
      # The current_user's role is a Convenor
      convenor: {
        # User being assigned is an tutor?
        #   A convenor current_user can demote them to a student
        tutor: {     student: [:demote_user] },
        # User being assigned is an student?
        #   A convenor current_user can promote them to a student
        student: {   tutor: [:promote_user] },
        # User being assigned has no role?
        #   A convenor current_user can create a user to either a student or tutor role
        nil: {       student: [:create_user],
                     tutor: [:create_user] }
      }
    }

    # What can admins do with users?
    admin_role_permissions = [
      :create_user,
      :list_users,
      :update_user,
      :get_user,

      :upload_csv,
      :download_system_csv,
      :download_unit_csv,

      :create_unit,
      :admin_units,
      :convene_units,
      :get_all_units,
      :get_staff_list,
      :rollover,

      :get_unit_roles,

      :handle_teaching_period,
      :handle_campuses,
      :handle_activity_types,

      :get_teaching_periods,

      :admin_overseer,
      :use_overseer,

      :get_scorm_token
    ]

    # What can auditors do with users?
    auditor_role_permissions = [
      :list_users,
      :get_staff_list,

      :get_unit_roles,
      :get_all_units,

      :audit_units,

      :get_teaching_periods,
      :use_overseer,
      :get_scorm_token
    ]

    # What can convenors do with users?
    convenor_role_permissions = [
      :get_all_units,
      :promote_user,
      :list_users,
      :create_user,
      :update_user,
      :demote_user,
      :upload_csv,
      :download_unit_csv,
      :create_unit,
      :get_unit_roles,
      :convene_units,
      :get_staff_list,
      :get_teaching_periods,
      :use_overseer,
      :get_scorm_token
    ]

    # What can tutors do with users?
    tutor_role_permissions = [
      :get_unit_roles,
      :download_unit_csv,
      :get_teaching_periods,
      :get_scorm_token
    ]

    # What can students do with users?
    student_role_permissions = [
      :get_teaching_periods,
      :get_scorm_token
    ]

    # Return the permissions hash
    {
      change_role: change_role_permissions,
      admin: admin_role_permissions,
      auditor: auditor_role_permissions,
      convenor: convenor_role_permissions,
      tutor: tutor_role_permissions,
      student: student_role_permissions
    }
  end

  def self.default
    user = new
    institution_email_domain = Doubtfire::Application.config.institution[:email_domain]
    user.username   = 'username'
    user.first_name = 'First'
    user.last_name  = 'Last'
    user.email      = "XXXXXXX@#{institution_email_domain}"
    user.nickname   = 'Nickname'
    user.role_id    = Role.student_id
    user
  end

  def self.role_for(user)
    user.role
  end

  def email_required?
    false
  end

  # Get all of the currently valid auth tokens
  def valid_auth_tokens
    auth_tokens.where("auth_token_expiry > :now", now: Time.zone.now)
  end

  def name
    fn = first_name.split.first
    # fn = nickname
    sn = last_name

    fn = "#{fn[0..11]}..." if fn.length > 15

    sn = "#{sn[0..11]}..." if sn.length > 15

    "#{fn} #{sn}"
  end

  def self.export_to_csv
    exportables = csv_columns.map { |col| col == 'role' ? 'role_id' : col }
    CSV.generate do |row|
      row << User.attribute_names.select { |attribute| exportables.include? attribute }.map do |attribute|
        # rename encrypted_password key to just password and role_id key to just role
        if attribute == 'encrypted_password'
          'password'
        elsif attribute == 'role_id'
          'role'
        else
          attribute
        end
      end
      User.order('id').each do |user|
        row << user.attributes.select { |attribute| exportables.include? attribute }.map do |key, value|
          # pass in a blank encrypted_password and the role name instead of just role_id
          if key == 'encrypted_password'
            ''
          elsif key == 'role_id'
            Role.find(value).name
          else
            value
          end
        end
      end
    end
  end

  def self.missing_headers(row, headers)
    headers - row.to_hash.keys
  end

  def self.csv_columns
    %w(username first_name last_name email student_id nickname role)
  end

  def self.import_from_csv(current_user, file)
    success = []
    errors = []
    ignored = []

    data = FileHelper.read_file_to_str(file)

    CSV.parse(data,
              headers: true,
              header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip.tr(' ', '_') unless hdr.nil? }],
              converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      next if row[0] =~ /(email)|(username)/

      begin
        missing = missing_headers(row, csv_columns)
        if missing.count > 0
          errors << { row: row, message: "Missing headers: #{missing.join(', ')}" }
          next
        end

        email = row['email']
        first_name = row['first_name']
        last_name = row['last_name']
        username = row['username']
        nickname = row['nickname']
        role = row['role']

        pass_checks = true
        %w(username email role first_name).each do |col|
          next if row[col].present?

          errors << { row: row, message: "The #{col} cannot be blank or empty" }
          pass_checks = false
          break
        end

        next unless pass_checks

        unless email =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
          errors << { row: row, message: "Invalid email address (#{email})" }
          next
        end

        new_role = Role.with_name(role)
        username = username.downcase # ensure that find by username uses lowercase

        if new_role.nil?
          errors << { row: row, message: "Unable to find role #{new_role}" }
          next
        end

        #
        # If the current user is allowed to create a user in this role
        #
        if AuthorisationHelpers.authorise?(current_user, User, :create_user, User.get_change_role_perm_fn, [:nil, new_role.to_sym])
          #
          # Find and update or create
          #
          user = User.find_or_create_by(username: username) do |new_user|
            new_user.first_name         = first_name.titleize
            new_user.last_name          = last_name.titleize
            new_user.email              = email
            new_user.nickname           = nickname
            new_user.role_id            = new_role.id
            new_user.encrypted_password = BCrypt::Password.create('password')
          end

          # will not be persisted initially as password cannot be blank - so can check
          # which were created using this - will persist changes imported
          if user.new_record?
            user.save!
            success << { row: row, message: "Added user #{username} as #{role}." }
          else
            ignored << { row: row, message: "User #{username} already existed." }
          end
        end
      rescue Exception => e
        errors << { row: row, message: e.message }
      end
    end

    {
      success: success,
      ignored: ignored,
      errors: errors
    }
  end
end
