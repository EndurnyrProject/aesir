defmodule Aesir.ZoneServer.MechanicsSupervisorTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts

  test "item scripts are compiled at zone boot" do
    assert Code.ensure_loaded?(CompiledItemScripts)
    assert function_exported?(CompiledItemScripts, :on_use, 2)
  end
end
