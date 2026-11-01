defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmSelfprovoke do
  @moduledoc """
  Self-Provoke (SM_SELFPROVOKE), used by Aloevera.

  Renewal and pre-renewal both start level-one Provoke on the caster for
  30 seconds with a guaranteed initial chance, while retaining status immunity
  and prevention. A successful start shows the ordinary Provoke visual,
  conditionally cancels a cancellable cast, and checks equipment coma.

  Player-local consequences are returned to the owning session rather than
  sent back through its mailbox. Other caster types keep their normal status
  notification path.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 473,
    name: :sm_selfprovoke,
    display_name: "Provoke Self",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :none,
    requires: [],
    status: :sc_provoke,
    duration: [30_000]

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:local_effects, Active.caster(), [Active.effect()]}
  def cast(caster, {:unit, _target}, level, definition),
    do: cast(caster, :self, level, definition)

  def cast(caster, :self, level, definition) do
    adapter = Caster.for(caster)
    type = adapter.unit_type(caster)
    id = adapter.id(caster)

    result =
      StatusInterpreter.apply_status_with_events(type, id, :sc_provoke,
        val1: level,
        caster_id: id,
        source_type: type,
        duration: Enum.at(definition.duration, level - 1, List.last(definition.duration))
      )

    finish(caster, level, result)
  end

  defp finish(%PlayerState{} = caster, level, {:ok, events}) do
    effects = [
      {:player, {:status_events, events}},
      {:player, {:skill_visual, 6, level}},
      {:player, {:conditional_cast_cancel}}
    ]

    {:local_effects, caster, effects ++ coma(caster)}
  end

  defp finish(%PlayerState{} = caster, _level, {:error, reason, events}) do
    failure = if reason == :immune, do: [], else: [{:player, {:skill_failed, 473}}]
    {:local_effects, caster, [{:player, {:status_events, events}} | failure]}
  end

  defp finish(caster, level, {:ok, _events}) do
    adapter = Caster.for(caster)
    id = adapter.id(caster)
    {map, x, y} = adapter.position(caster)

    Broadcast.to_in_range(map, x, y, Config.view_range(), %SkillEffect{
      skill_id: 6,
      level: level,
      target_id: id,
      src_id: id,
      result: 1
    })

    if adapter.unit_type(caster) == :mob do
      case UnitRegistry.get_unit(:mob, id) do
        {:ok, {_module, _state, pid}} when is_pid(pid) -> MobSession.provoke(pid, {:mob, id})
        _missing -> :ok
      end
    end

    {:ok, caster}
  end

  defp finish(caster, _level, {:error, _reason, _events}), do: {:ok, caster}

  defp coma(caster) do
    combatant = PlayerState.to_combatant(caster)

    if EquipComa.bonus?(combatant) and EquipComa.trigger?(combatant, combatant),
      do: [{:player, {:apply_coma, {:player, caster.character_id}, %{passive?: true}}}],
      else: []
  end
end
