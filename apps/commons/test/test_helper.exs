alias Aesir.GameModeTestSupport

Mimic.copy(Application)

GameModeTestSupport.start(exclude: [:distributed])

Ecto.Adapters.SQL.Sandbox.mode(Aesir.Repo, :manual)
