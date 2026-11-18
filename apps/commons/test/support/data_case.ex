defmodule Aesir.DataCase do
  @moduledoc """
  Case template for tests that touch `Aesir.Repo`.

  Each test checks out its own sandbox connection and rolls it back on exit:

    * `async: true` (prefer it) gives the test a private connection. The test
      process and anything carrying it in `$callers` (`Task.async/1`, `Task.start/1`) can
      use it; any other process needs `Ecto.Adapters.SQL.Sandbox.allow/3`.
    * `async: false` shares the connection with every process, for tests whose DB work
      runs in processes outside the test's tree (Horde entries, supervised sessions).

  Insert rows with `Aesir.Factory`, never with hand-written changeset pipelines.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Aesir.DataCase

      alias Aesir.Repo
      alias Ecto.Adapters.SQL
    end
  end

  setup tags do
    Aesir.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    alias Ecto.Adapters.SQL
    pid = SQL.Sandbox.start_owner!(Aesir.Repo, shared: not tags[:async])
    on_exit(fn -> SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
