env = (ENV["IRB_PROMPT"] || ENV["APP_ENV"] || ENV["RACK_ENV"] || "").upcase
if env == "PRODUCTION" || env == "DEPLOYMENT"
  color = "31"
else
  color = "33"
end
prompt = "%03n "
prompt += "\e[#{color}m#{env} " if env
prompt += "\e[33m"

IRB.conf[:PROMPT][:CUSTOM] = {
  PROMPT_I: "#{prompt}>>\e[0m ",
  PROMPT_N: "#{prompt}>>\e[0m ",
  PROMPT_S: "#{prompt}%l>\e[0m ",
  PROMPT_C: "#{prompt}?>\e[0m ",
  RETURN:   "\e[32m=>\e[0m %s\n",
}
IRB.conf[:PROMPT_MODE] = :CUSTOM

IRB.conf[:USE_AUTOCOMPLETE] = false
