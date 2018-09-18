module TestHelpers

  module AccountHelper

    ##################################################
    # Student user
    ##################################################

    def student_users
      User.where(role_id: 1)
    end

    def first_student_user
      student_users.first
    end

    def last_student_user
      student_users.last
    end

    ##################################################
    # Tutor user
    ##################################################

    def tutor_users
      User.where(role_id: 2)
    end

    def first_tutor_user
      tutor_users.first
    end

    def last_tutor_user
      tutor_users.last
    end

    ##################################################
    # Convenor user
    ##################################################

    def convenor_users
      User.where(role_id: 3)
    end

    def first_convenor_user
      convenor_users.first
    end

    def convenor_user
      convenor_users.last
    end

    ##################################################
    # Admin user
    ##################################################

    def admin_users
      User.where(role_id: 4)
    end

    def first_admin_user
      admin_users.first
    end

    def last_admin_user
      admin_users.last
    end

  end

end