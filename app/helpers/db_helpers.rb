module DbHelpers
  def db_concat(*args)
    env = ENV['RAILS_ENV'] || 'development'
    adapter = ActiveRecord::Base.configurations[env]['adapter'].to_sym
    args.map! { |arg| arg.class == Symbol ? arg.to_s : arg }

    case adapter
    when :mysql, :mysql2
      "CONCAT(#{args.join(',')})"
    when :sqlserver
      args.join('+')
    else
      args.join('||')
    end
  end

  module_function :db_concat
end
