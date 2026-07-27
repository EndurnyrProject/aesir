defmodule Aesir.MimicMode do
  @moduledoc """
  Scoped replacement for `Mimic.set_mimic_global/1`.

  Mimic hands global mode back only when its server processes the owning
  process's `:DOWN`, and it monitors that process only if the process also set
  a stub or an expectation. A test that goes global without stubbing therefore
  pins the mode to a pid that is already gone, and every later test that calls
  `stub/3` raises "Stub cannot be called by the current process. Only the
  global owner is allowed." - whole modules at a time, since sync test modules
  run back to back. Even when the owner is monitored, the `:DOWN` races the
  next test starting.

  Use it wherever Mimic's own `setup :set_mimic_global` would go:

      setup {Aesir.MimicMode, :global}

  The mode is handed back before the next test runs.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc """
  Runs the test in Mimic's global mode and restores private mode afterwards.
  """
  @spec global(map()) :: :ok
  def global(_context \\ %{}) do
    :ok = Mimic.set_mimic_global()
    on_exit(&Mimic.set_mimic_private/0)
    :ok
  end
end
