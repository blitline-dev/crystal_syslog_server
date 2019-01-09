class TypeTable
  FACILITIES = %w{kernel user mail system security syslog lpd nntp uucp time security ftpd ntpd logaudit logalert clock local0 local1 local2 local3 local4 local5 local6 local7}

  def self.define(log_type : Int32)
    facilty_index = log_type / 8
    severity = log_type % 8
    facility = FACILITIES[facilty_index]
    return [severity, facility]
  end
end
