defmodule Aesir.ZoneServer.Content.Npc.Woe.ControllerTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Content.Npc.Woe.Controller
  alias Aesir.ZoneServer.Npc.Registry

  setup do
    Registry.reload([Controller])
    on_exit(fn -> :persistent_term.erase(Registry) end)
    :ok
  end

  test "registers the controller with OnInit as its only event" do
    assert [{Controller, placement}] = Registry.by_name("WoeController")
    assert is_integer(Registry.entity_id(placement))
    assert Controller.events() == ["OnInit"]
  end
end
