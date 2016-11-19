env = (ENV["IRB_PROMPT"] || ENV["RACK_ENV"] || "unknown").upcase
if env == "PRODUCTION" or env == "DEPLOYMENT"
  color = "31"
else
  color = "33"
end

IRB.conf[:PROMPT][:CUSTOM] = {
  PROMPT_I: "%03n \e[#{color}m#{env} >>\e[0m ",
  PROMPT_N: "%03n \e[#{color}m#{env} \e[1;33m>>\e[0m ",
  PROMPT_S: nil,
  PROMPT_C: "%03n \e[#{color}m#{env} \e[33m?>\e[0m ",
  RETURN:   "\e[#{color}m#{env} \e[32m=>\e[0m %s\n"
}
IRB.conf[:PROMPT_MODE] = :CUSTOM
