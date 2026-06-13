ExUnit.start(exclude: [:distributed])

Ecto.Adapters.SQL.Sandbox.mode(Aesir.Repo, :manual)
