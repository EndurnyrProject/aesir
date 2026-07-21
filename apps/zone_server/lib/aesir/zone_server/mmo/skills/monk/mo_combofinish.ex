defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoCombofinish do
  @moduledoc "Raging Thrust (MO_COMBOFINISH)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 273,
    name: :mo_combofinish,
    display_name: "Raging Thrust",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    sp_cost: [3, 4, 5, 6, 7],
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_combo}
  def validate(caster, {:unit, target_id}, _level, _definition) do
    case Combo.validate(caster.combo, :thrust, target_id, now()) do
      {:ok, _target} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, target} <- Combo.validate(caster.combo, :thrust, target_id, now()),
         {:ok, target_type, _position} <- Combat.resolve_target_position(target_id),
         {:ok, ^target} <- Combo.validate(caster.combo, :thrust, {target_type, target_id}, now()),
         :ok <-
           Combat.execute_skill_attack(
             caster,
             target_id,
             skill_options(caster, level, definition)
           ) do
      {:ok, %{caster | combo: Combo.cancel(caster.combo)}}
    else
      {:error, _reason} = error -> error
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  defp skill_options(caster, level, definition) do
    [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: Formulas.thrust_ratio(level, caster.stats.base_stats.str),
      hit_count: Formulas.thrust_hit_count(),
      skip_crit: true
    ]
  end

  defp now, do: System.monotonic_time(:millisecond)
end
