D = Steep::Diagnostic

target :app do
  check 'lib'
  signature 'sig'

  library 'uri', 'logger', 'monitor'
  library 'bbk-utils'
  configure_code_diagnostics(D::Ruby.strict)
end

