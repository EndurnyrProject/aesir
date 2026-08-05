defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHammerfall do
  @moduledoc """
  Hammer Fall (BS_HAMMERFALL) attempts to stun enemies in a 5x5 ground-targeted
  area after a one-second delay without dealing damage.
  """

  # Denylist gap: this player-only cast crashes when invoked by a mob.
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
    require_weapon: [:dagger, :one_handed_sword, :one_handed_axe, :two_handed_axe, :mace]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @delay_ms 1_000
  @stun_duration_ms 4_500

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
    payload = %{caster_id: caster_id, map_name: map_name, center: {x, y}, level: level}
    Skill.defer(__MODULE__, payload, @delay_ms)
    {:ok, caster}
  end

  @doc "Attempts Hammer Fall's delayed stun against enemies in the targeted area."
  @impl Active
  @spec deferred(impact(), PlayerState.t()) :: :ok
  def deferred(
        %{caster_id: caster_id, map_name: map_name, center: center, level: level},
        _caster
      ) do
    map_name
    |> Combat.splash_targets(center, definition().splash_radius, caster_id)
    |> Enum.each(fn
      {:mob, target_id} ->
        StatusInterpreter.apply_status(:mob, target_id, :sc_stun,
          caster_id: caster_id,
          val1: level,
          duration: @stun_duration_ms,
          success_rate: 20 + level * 10
        )

      _other ->
        :ok
    end)
  end
end
