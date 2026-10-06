defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicRod do
  @moduledoc """
  Magic Rod (SC_MAGICROD).

  A sub-second self-buff that intercepts a magic skill hit after damage
  reductions and converts it to SP. It restores `spell_sp * val2 / 100` SP,
  where `spell_sp` is the skill's raw SP cost and `val2 = 20 * level`.

  Interception is narrow: only a `:magic`
  hit flagged `from_caster?` is caught. `src == dsrc` asks whether the damage
  came straight from the caster rather than from a placed skill unit, so a
  directly-cast spell is absorbed **including its splash** (Fireball), while a
  ground unit's tick (Storm Gust, Fire Wall) and status DoTs are not. Physical
  and misc hits pass through untouched. Over-absorbing is far worse than
  under-absorbing, so the hook fails closed: any hit whose `hit_info` does not
  positively assert both conditions is ignored.

  Water Ball is special-cased exactly as rAthena does: the skill's SP cost pays
  for the whole barrage, so above level 1 the gain is divided by
  `(lv ||| 1) * (lv ||| 1)` to estimate the cost of the single ball absorbed.

  Water Ball currently arrives through a skill unit in Aesir, so the split
  applies when it is delivered directly by its caster.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_magicrod,
    no_dispel: false,
    no_save: true,
    properties: [:buff],
    target_types: [:player],
    icon: :magicrod

  import Bitwise, only: [|||: 2]

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @waterball_id 86

  @doc "Intercepts a direct magic skill hit, returning :miss for a caught spell."
  @spec intercept({atom(), integer()}, Aesir.ZoneServer.Mmo.StatusEntry.t(), map()) ::
          :miss | :continue
  def intercept(
        target,
        instance,
        %{dmg_type: :magic, from_caster?: true, skill_id: skill_id, skill_level: skill_level}
      )
      when is_integer(skill_id) and is_integer(skill_level) do
    skill_id
    |> spell_sp_cost(skill_level)
    |> absorbed_sp(skill_id, skill_level, instance.val2)
    |> then(&Helpers.restore_sp(target, &1))

    :miss
  end

  def intercept(_target, _instance, _hit_info), do: :continue

  # A skill absent from the catalog cannot have been cast; it contributes no SP,
  # but the hit is still absorbed. A mob casting above the skill's player max
  # level (its rows routinely do) extrapolates rather than clamping, via the
  # shared catalog accessor.
  @spec spell_sp_cost(integer(), integer()) :: non_neg_integer()
  defp spell_sp_cost(skill_id, skill_level) do
    case Catalog.by_id(skill_id) do
      {:ok, %{sp_cost: sp_cost}} -> Catalog.sp_cost_at(sp_cost, skill_level)
      :error -> 0
    end
  end

  @spec absorbed_sp(non_neg_integer(), integer(), integer(), integer()) :: non_neg_integer()
  defp absorbed_sp(spell_sp, @waterball_id, skill_level, val2) when skill_level > 1 do
    div(div(spell_sp * val2, 100), (skill_level ||| 1) * (skill_level ||| 1))
  end

  defp absorbed_sp(spell_sp, _skill_id, _skill_level, val2), do: div(spell_sp * val2, 100)
end
