defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoChaincombo do
  @moduledoc """
  Raging Quadruple Blow (MO_CHAINCOMBO).

  Renewal: 250 plus 50 per level percent, doubled and split into six hits with
  a knuckle instead of four, for 4 plus level SP. Pre-renewal: 150 plus 50 per
  level percent split into four hits for 10 plus level SP.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 272,
    name: :mo_chaincombo,
    display_name: "Raging Quadruple Blow",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    hit_count: -4,
    sp_cost: [renewal: [5, 6, 7, 8, 9], pre_renewal: [11, 12, 13, 14, 15]],
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_combo}
  def validate(caster, {:unit, target_id}, _level, _definition) do
    case Combo.validate(caster.combo, :quadruple, target_id, now()) do
      {:ok, _target} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    knuckle? = Stats.weapon_type(caster.stats.equipment) == :knuckle
    now = now()

    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: Formulas.quadruple_ratio(level, knuckle?),
      hit_divisions: Formulas.quadruple_hit_count(knuckle?),
      skip_crit: true
    ]

    with :ok <- Root.check_cast(:player, caster.character_id, definition.id),
         :ok <- validate(caster, {:unit, target_id}, level, definition),
         {:ok, target} <- Combo.validate(caster.combo, :quadruple, target_id, now),
         {:ok, target_type, _position} <- Combat.resolve_target_position(target_id),
         {:ok, ^target} <- Combo.validate(caster.combo, :quadruple, {target_type, target_id}, now),
         :ok <- Combat.execute_skill_attack(caster, target_id, opts),
         delay <- Enum.at(definition.after_cast_delay, level - 1, 0),
         {:ok, combo} <-
           Combo.open_follow_up(caster, :quadruple, :quadruple, target, now, delay) do
      {:ok, %{caster | combo: combo}}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  defp now, do: System.monotonic_time(:millisecond)
end
