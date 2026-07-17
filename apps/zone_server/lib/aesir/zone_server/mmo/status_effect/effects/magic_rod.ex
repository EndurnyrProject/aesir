defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicRod do
  @moduledoc """
  Magic Rod (SC_MAGICROD).

  A sub-second self-buff that absorbs a single-target magic spell aimed at the
  caster and converts it to SP. Via the pre-damage `absorb_damage` hook it zeroes
  the incoming hit and restores `spell_sp * val2 / 100` SP, where `spell_sp` is
  the absorbed skill's own SP cost at the level it was cast and `val2 = 20 * level`
  (rAthena `status.cpp:10911`).

  Absorption is narrow (rAthena `skill.cpp:2864-2875`, guarded by
  `dmg.flag&BF_MAGIC` at `skill.cpp:2781` and `src == dsrc`): only a `:magic`
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

  That branch is currently unreachable: Aesir models Water Ball as a ground
  skill-unit, whereas rAthena delivers it as a direct repeating cast from the
  caster — which is precisely why the split exists there. The rule is kept,
  traceable to source, and starts applying if Water Ball's delivery is ever
  corrected to match rAthena.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_magicrod,
    no_dispel: false,
    no_save: true,
    properties: [:buff],
    icon: :magicrod

  import Bitwise, only: [|||: 2]

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @waterball_id 86

  @impl true
  def absorb_damage(
        target,
        instance,
        %{dmg_type: :magic, from_caster?: true, skill_id: skill_id, skill_level: skill_level},
        _context
      )
      when is_integer(skill_id) and is_integer(skill_level) do
    skill_id
    |> spell_sp_cost(skill_level)
    |> absorbed_sp(skill_id, skill_level, instance.val2)
    |> then(&Helpers.restore_sp(target, &1))

    {:ok, 0, instance}
  end

  @impl true
  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  # A skill absent from the catalog cannot have been cast; it contributes no SP,
  # but the hit is still absorbed.
  @spec spell_sp_cost(integer(), integer()) :: non_neg_integer()
  defp spell_sp_cost(skill_id, skill_level) do
    case Catalog.by_id(skill_id) do
      {:ok, %{sp_cost: sp_cost}} -> Enum.at(sp_cost, skill_level - 1, 0)
      :error -> 0
    end
  end

  @spec absorbed_sp(non_neg_integer(), integer(), integer(), integer()) :: non_neg_integer()
  defp absorbed_sp(spell_sp, @waterball_id, skill_level, val2) when skill_level > 1 do
    div(div(spell_sp * val2, 100), (skill_level ||| 1) * (skill_level ||| 1))
  end

  defp absorbed_sp(spell_sp, _skill_id, _skill_level, val2), do: div(spell_sp * val2, 100)
end
