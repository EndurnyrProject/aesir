defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaSeismicweapon do
  @moduledoc """
  Seismic Weapon (SA_SEISMICWEAPON). Endows an ally's weapon with the earth
  element, applying SC_EARTHWEAPON.

  rAthena renewal (`skills/mage/endowblaze.cpp:15-27`): 100% success at every
  level - the pre-renewal `60+lv*10` roll and its weapon-unequip penalty on
  failure are not implemented. Casting on an unarmed target fails outright,
  before any cost is charged (`dstsd->status.weapon == W_FIST`); a non-player
  target has no `dstsd` and skips the check entirely.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 283,
    name: :sa_seismicweapon,
    status: :sc_earthweapon,
    display_name: "Seismic Weapon",
    max_level: 5,
    target_type: :target_ally,
    damage_type: :no_damage,
    element: :earth,
    range: 9,
    cast_time: List.duplicate(1000, 5),
    fixed_cast_time: List.duplicate(1000, 5),
    sp_cost: List.duplicate(40, 5),
    item_cost: [%{id: 6363, amount: 1}],
    duration: [600_000, 900_000, 1_200_000, 1_500_000, 1_800_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :bare_handed}
  def validate(caster, target, _level, _definition) do
    check_weapon(caster, Active.resolve_target_id(caster, target))
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, target, level, definition) do
    target_id = Active.resolve_target_id(caster, target)
    duration = Enum.at(definition.duration, level - 1)

    case StatusInterpreter.apply_status(:player, target_id, :sc_earthweapon,
           val1: level,
           caster_id: caster_id,
           duration: duration
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  # rAthena only rejects a bare-handed *player* target (`BL_CAST(BL_PC,
  # target)`); a target that does not resolve to a player has no `dstsd` and
  # skips the check.
  @spec check_weapon(PlayerState.t(), non_neg_integer()) :: :ok | {:error, :bare_handed}
  defp check_weapon(%{character_id: caster_id} = caster, caster_id) do
    weapon_check(caster.stats.equipment)
  end

  defp check_weapon(_caster, target_id) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target_state, _pid}} -> weapon_check(target_state.stats.equipment)
      {:error, :not_found} -> :ok
    end
  end

  defp weapon_check(equipment) do
    if PlayerStats.weapon_type(equipment) == :fist do
      {:error, :bare_handed}
    else
      :ok
    end
  end
end
