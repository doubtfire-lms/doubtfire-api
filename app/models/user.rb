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

class User < ActiveRecord::Base
  include AuthenticationHelpers

  ###
  # Authentication
  ###

  # Auth token encryption settings
  attr_encrypted :auth_token,
                 key: Doubtfire::Application.secrets.secret_key_attr,
                 encode: true,
                 attribute: 'authentication_token'

  # User authentication config
  if AuthenticationHelpers.aaf_auth?
    #
    # Decodes a JWS against the JWT secret, returning JWT data or nil if no data
    # could be decoded
    #
    def self.decode_jws(jws)
      JSON::JWT.decode(jws.to_s, Doubtfire::Application.secrets.secret_key_aaf)
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

  def password= (value)
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
  # Extends an existing auth_token if needed
  #
  def extend_authentication_token(remember)
    # Extending a nil token will just create one first
    if auth_token.nil?
      generate_authentication_token! false
      return
    end

    # Default expire time
    expiry_time = Time.zone.now + 2.hours

    # Extended expiry times only apply to students and convenors
    if remember
      student_expiry_time = Time.zone.now + 2.weeks
      tutor_expiry_time = Time.zone.now + 1.week
      expiry_time =
        if role == Role.student || role == :student
          student_expiry_time
        elsif role == Role.tutor || role == :tutor
          tutor_expiry_time
        else
          expiry_time
        end
    end

    self.auth_token_expiry = expiry_time
    save
  end

  #
  # Force-generates a new authentication token, regardless of whether or not
  # it is actually expired
  #
  def generate_authentication_token!(remember)
    # Loop until new unique auth token is found
    token = loop do
      token = Devise.friendly_token
      break token unless User.find_by_auth_token(token)
    end
    # Set and return new auth token
    self.auth_token = token
    extend_authentication_token(remember)
    save
    token
  end

  #
  # Generate an authentication token that will expire in 30 seconds
  #
  def generate_temporary_authentication_token!
    generate_authentication_token!(false)
    self.auth_token_expiry = Time.zone.now + 30.seconds
  end

  #
  # Deletes authentication token
  #
  def reset_authentication_token!
    self.auth_token = nil
    self.auth_token_expiry = Time.zone.now - 1.week
    save
  end

  #
  # Returns whether the authentication token has expired
  #
  def authentication_token_expired?
    auth_token_expiry.nil? || auth_token_expiry <= Time.zone.now
  end

  ###
  # Schema
  ###

  # Model associations
  belongs_to  :role # Foreign Key
  has_many    :unit_roles, dependent: :destroy
  has_many    :projects

  # Model validations/constraints
  validates :first_name,  presence: true
  validates :last_name,   presence: true
  validates :role_id,     presence: true
  validates :username,    presence: true, uniqueness: { case_sensitive: false }
  validates :email,       presence: true, uniqueness: { case_sensitive: false }, format: {with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i}
  validates :student_id,  uniqueness: true, allow_nil: true

  # Queries
  scope :tutors,    -> { joins(:role).where('roles.id = :tutor_role or roles.id = :convenor_role or roles.id = :admin_role', tutor_role: Role.tutor_id, convenor_role: Role.convenor_id, admin_role: Role.admin_id) }
  scope :convenors, -> { joins(:role).where('roles.id = :convenor_role or roles.id = :admin_role', convenor_role: Role.convenor_id, admin_role: Role.admin_id) }
  scope :admins,    -> { joins(:role).where('roles.id = :admin_role', admin_role: Role.admin_id) }

  def self.teaching(unit)
    User.joins(:unit_roles).where('unit_roles.unit_id = :unit_id and ( unit_roles.role_id = :tutor_role_id or unit_roles.role_id = :convenor_role_id) ', unit_id: unit.id, tutor_role_id: Role.tutor_id, convenor_role_id: Role.convenor_id)
  end

  def username=(name)
    # strip S or s from start of ids in the form S1234567 or S123456X
    truncate_s_match = (name =~ /^[Ss]\d{6,10}([Xx]|\d)$/)
    name[0] = '' if !truncate_s_match.nil? && truncate_s_match.zero?
    self[:username] = name.downcase
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

  def self.get_change_role_perm_fn
    lambda do |role, perm_hash, other|
      from_role = other[0]
      to_role = other[1]

      (chg_roles = perm_hash[:change_role]) &&
        (role_hash = chg_roles[role]) &&
        (from_role_hash = role_hash[from_role]) &&
        from_role_hash[to_role]
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
        # User being assigned is an admin?
        #   An admin current_user can demote them to either a student, tutor or convenor
        admin: {     student: [ :demote_user  ],
                     tutor: [ :demote_user ],
                     convenor: [ :demote_user ] },
        # User being assigned is a convenor?
        #   An admin current_user can demote them to student or tutor
        #   An admin current_user can promote them to an admin
        convenor: {  student: [ :demote_user  ],
                     tutor: [ :demote_user  ],
                     admin: [ :promote_user ] },
        # User being assigned is a tutor?
        #   An admin current_user can demote them to a student
        #   An admin current_user can promote them to a convenor or admin
        tutor: {     student: [ :demote_user  ],
                     convenor: [ :promote_user ],
                     admin: [ :promote_user ] },
        # User being assigned is a student?
        #   An admin current_user can promote them to a tutor, convenor or admin
        student: {   tutor: [ :promote_user ],
                     convenor: [ :promote_user ],
                     admin: [ :promote_user ] },
        # User being assigned has no role?
        #   An admin current_user can create user to any role
        nil: {       student: [ :create_user  ],
                     tutor: [ :create_user  ],
                     convenor: [ :create_user ],
                     admin: [ :create_user  ] }
      },
      # The current_user's role is a Convenor
      convenor: {
        # User being assigned is an tutor?
        #   A convenor current_user can demote them to a student
        tutor: {     student: [ :demote_user  ] },
        # User being assigned is an student?
        #   A convenor current_user can promote them to a student
        student: {   tutor: [ :promote_user ] },
        # User being assigned has no role?
        #   A convenor current_user can create a user to either a student or tutor role
        nil: {       student: [ :create_user  ],
                     tutor: [ :create_user  ] }
      }
    }

    # What can admins do with users?
    admin_role_permissions = [
      :create_user,
      :upload_csv,
      :list_users,
      :download_system_csv,
      :download_unit_csv,
      :update_user,
      :create_unit,
      :act_tutor,
      :admin_units,
      :admin_users,
      :convene_units,
      :download_stats,
      :handle_teaching_period,
      :handle_campuses,
      :handle_activity_types,
      :get_teaching_periods,
      :rollover,
      :get_unit_activity_sets
    ]

    # What can convenors do with users?
    convenor_role_permissions = [
      :promote_user,
      :list_users,
      :create_user,
      :update_user,
      :demote_user,
      :upload_csv,
      :download_unit_csv,
      :create_unit,
      :act_tutor,
      :convene_units,
      :download_stats,
      :get_teaching_periods
    ]

    # What can tutors do with users?
    tutor_role_permissions = [
      :act_tutor,
      :download_unit_csv,
      :get_teaching_periods
    ]

    # What can students do with users?
    student_role_permissions = [
      :get_teaching_periods
    ]

    # Return the permissions hash
    {
      change_role: change_role_permissions,
      admin: admin_role_permissions,
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

  def role_id=(new_role_id)
    new_role = Role.find(new_role_id)
    new_role = Role.student if new_role.nil?

    fail_if_in_unit_role = [ Role.tutor, Role.convenor ] if new_role == Role.student
    fail_if_in_unit_role = [ Role.convenor ] if new_role == Role.tutor
    fail_if_in_unit_role = [] if new_role == Role.admin || new_role == Role.convenor

    for check_role in fail_if_in_unit_role do
      if unit_roles.where('role_id = :role_id', role_id: check_role.id).count > 0
        return role
      end
    end

    self[:role_id] = new_role.id
  end

  #
  # Change the user's role - but ensure that it remains valid based on their roles in units
  #
  def role=(new_role)
    self.role_id = new_role.id
  end

  def email_required?
    false
  end

  def name
    fn = first_name.split(' ').first
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

    CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip.tr(' ', '_') unless hdr.nil? } ],
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
          next unless row[col].nil? || row[col].empty?
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
        if AuthorisationHelpers.authorise?(current_user, User, :create_user, User.get_change_role_perm_fn, [ :nil, new_role.to_sym ])
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
      errors:  errors
    }
  end
end
