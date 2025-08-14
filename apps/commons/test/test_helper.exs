ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Aesir.Repo, :manual)

# Ensure Memento tables have correct schemas
Aesir.Commons.MementoTestHelper.ensure_tables_exist()
