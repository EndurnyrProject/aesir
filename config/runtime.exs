import Config

case System.get_env("AESIR_DB_MODE") do
  nil ->
    :ok

  "renewal" ->
    config :zone_server, db_mode: :renewal

  "pre_renewal" ->
    config :zone_server, db_mode: :pre_renewal

  value ->
    raise ArgumentError,
          "invalid AESIR_DB_MODE #{inspect(value)}; expected \"renewal\" or \"pre_renewal\""
end
