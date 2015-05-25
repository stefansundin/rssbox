prefix = ENV["RACK_ENV"] || "development"

IRB.conf[:PROMPT][:CUSTOM] = {
  PROMPT_I: "%03n \e[31m#{prefix} >>\e[0m ",
  PROMPT_N: "%03n \e[1;33m#{prefix} >>\e[0m ",
  PROMPT_S: nil,
  PROMPT_C: "%03n \e[33m#{prefix} ?>\e[0m ",
  RETURN:   "\e[32m=>\e[0m %s\n"
}
IRB.conf[:PROMPT_MODE] = :CUSTOM
