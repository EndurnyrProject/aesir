defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHammerfall do
  @moduledoc """
  Hammer Fall (BS_HAMMERFALL). One second after the cast, tries to stun every enemy
  in a 5x5 area around the targeted cell with a 20 plus 10 per level percent chance,
  dealing no damage, for 10 SP with a bladed or blunt weapon.

  Renewal stuns for 4.5 s; pre-renewal for 5 s.
  """

  # Requirement gap closed: this player-only cast crashes when invoked by a mob.
  use Aesir.ZoneServer.Mmo.Skill,
    id: 110,
    name: :bs_hammerfall,
    requires: [:player_state],
    display_name: "Hammer Fall",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 1,
    splash_radius: 2,
    sp_cost: List.duplicate(10, 5),
    duration: [renewal: List.duplicate(4_500, 5), pre_renewal: List.duplicate(5_000, 5)],
    require_weapon: [:dagger, :one_handed_sword, :one_handed_axe, :two_handed_axe, :mace],
    damage_splash: true

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastEnd
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @delay_ms 1_000

  @typedoc "The ground impact captured when Hammer Fall is cast."
  @type impact :: %{
          caster_id: pos_integer(),
          map_name: String.t(),
          center: {integer(), integer()},
          level: pos_integer()
        }

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(
        %{character_id: caster_id, map_name: map_name} = caster,
        {:ground, x, y},
        level,
        _definition
      ) do
    # The reference's ground cast end re-enters its no-damage cast end for every
    # enemy in the area at once: each target's cast-end tail runs then, and its
    # own one-second stun timer is armed from there. Only the stun lands later.
    for_each_enemy(map_name, {x, y}, caster_id, fn target_ref ->
      perform_castend_tail(caster, target_ref)
    end)

    payload = %{caster_id: caster_id, map_name: map_name, center: {x, y}, level: level}
    Skill.defer(__MODULE__, payload, @delay_ms)
    {:ok, caster}
  end

  @doc "Attempts Hammer Fall's delayed stun against enemies in the targeted area."
  @impl Active
  @spec deferred(impact(), PlayerState.t() | nil) :: :ok
  def deferred(%{caster_id: caster_id, map_name: map_name, center: center, level: level}, _caster) do
    for_each_enemy(map_name, center, caster_id, fn target_ref ->
      stun(target_ref, level, caster_id)
    end)
  end

  defp for_each_enemy(map_name, center, caster_id, fun) do
    map_name
    |> Combat.splash_targets(center, definition().splash_radius, caster_id)
    |> Enum.each(fun)
  end

  # The cast-end tail of one target, as the reference's per-target re-entry
  # makes it: the monster's skill-used event and, for the player caster, the
  # on-skill procs for that target too.
  defp perform_castend_tail(%PlayerState{} = caster, target_ref),
    do: CastEnd.complete_target(caster, definition().id, {:unit, target_ref}, on_skill: true)

  defp perform_castend_tail(_no_player_caster, _target_ref), do: :ok

  defp stun({:mob, target_id}, level, caster_id) do
    StatusInterpreter.apply_status(:mob, target_id, :sc_stun,
      caster_id: caster_id,
      val1: level,
      duration: Enum.at(definition().duration, level - 1),
      success_rate: 20 + level * 10
    )
  end

  defp stun(_other, _level, _caster_id), do: :ok
end
