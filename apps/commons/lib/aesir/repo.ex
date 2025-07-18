defmodule Aesir.Repo do
  use Ecto.Repo,
    otp_app: :commons,
    adapter: Ecto.Adapters.Postgres
end
