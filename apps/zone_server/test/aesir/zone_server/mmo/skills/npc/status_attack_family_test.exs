defmodule Aesir.ZoneServer.Mmo.Skills.Npc.StatusAttackFamilyTest do
  @moduledoc """
  Cross-module coverage for the eight weapon-class NPC status-attack skills:
  each resolves from the skill catalog by its rAthena id, is a weapon-class
  hit in the documented element, delegates to `StatusStrike` for its status
  atom, and that status atom has a registered effect module.
  """

  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcBleeding
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcBlindattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcCurseattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcPoison
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcPoisonattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSilenceattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSleepattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcStunattack
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 3000
  @caster_id 999

  @family [
    {NpcStunattack, 179, :npc_stunattack, :neutral, :sc_stun},
    {NpcPoisonattack, 188, :npc_poisonattack, :poison, :sc_poison},
    {NpcPoison, 176, :npc_poison, :neutral, :sc_poison},
    {NpcBlindattack, 177, :npc_blindattack, :neutral, :sc_blind},
    {NpcCurseattack, 181, :npc_curseattack, :shadow, :sc_curse},
    {NpcSilenceattack, 178, :npc_silenceattack, :neutral, :sc_silence},
    {NpcSleepattack, 182, :npc_sleepattack, :neutral, :sc_sleep},
    {NpcBleeding, 660, :npc_bleeding, :neutral, :sc_bleeding}
  ]

  defp caster, do: %PlayerState{character_id: @caster_id}

  defp known_status_ids, do: Effects.all() |> Enum.map(& &1.id()) |> MapSet.new()

  for {module, id, name, element, status} <- @family do
    describe "#{inspect(module)}" do
      test "resolves from the catalog by its rAthena skill id" do
        assert {:ok, definition} = Catalog.by_id(unquote(id))
        assert definition.name == unquote(name)
        assert definition.damage_kind == :weapon
        assert definition.damage_type == :damage
        assert definition.element == unquote(element)
        assert {:ok, unquote(module)} = Catalog.active_module_for(unquote(name))
      end

      test "its status atom has a registered effect module" do
        assert unquote(status) in known_status_ids()
      end

      test "cast/4 hits and applies its status on a connecting hit" do
        {:ok, definition} = Catalog.by_id(unquote(id))
        caster = caster()

        expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
          assert opts[:element] == unquote(element)
          assert opts[:skill_ratio] == 100
          {:ok, %{hit?: true}}
        end)

        stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

        expect(StatusInterpreter, :apply_status, fn :mob, @target_id, unquote(status), opts ->
          assert opts[:caster_id] == @caster_id
          :ok
        end)

        assert {:ok, ^caster} =
                 unquote(module).cast(caster, {:unit, @target_id}, 3, definition)
      end

      test "cast/4 skips the status on a miss" do
        {:ok, definition} = Catalog.by_id(unquote(id))
        caster = caster()

        stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
          {:ok, %{hit?: false}}
        end)

        reject(&StatusInterpreter.apply_status/4)

        assert {:ok, ^caster} =
                 unquote(module).cast(caster, {:unit, @target_id}, 3, definition)
      end
    end
  end
end
