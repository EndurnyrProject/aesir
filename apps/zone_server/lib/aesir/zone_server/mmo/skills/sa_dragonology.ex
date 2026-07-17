defmodule Aesir.ZoneServer.Mmo.Skills.SaDragonology do
  @moduledoc """
  Dragonology (SA_DRAGONOLOGY). Grants flat INT plus race-conditional damage
  bonuses and resistance against Dragon-race units.

  rAthena renewal `status_calc_pc_additional` (`status.cpp:4682-4700`):

      if((skill=pc_checkskill(sd,SA_DRAGONOLOGY))>0) {
        uint8 dragon_matk = skill * 2;
        skill = skill * 4;
        sd->right_weapon.addrace[RC_DRAGON]+=skill;
        if( !battle_config.left_cardfix_to_right )
          sd->left_weapon.addrace[RC_DRAGON] += skill;
        sd->indexed_bonus.magic_addrace[RC_DRAGON]+=dragon_matk;
        sd->indexed_bonus.subrace[RC_DRAGON]+=skill;
      }

  So the block grants four things at once: flat INT (`+(lv+1)/2`, this
  module's `int_bonus/2`), `+4*lv%` physical ATK vs Dragon race
  (`addrace`), `+2*lv%` MATK vs Dragon race (`magic_addrace`), and
  `-4*lv%` damage taken from Dragon-race attackers (`subrace` — the
  "Dragon-race resistance" the architecture flagged as unverified; it is
  real and implemented here, sharing rAthena's `subrace` magnitude with the
  physical rider since `battle_calc_damage`'s cardfix applies it uniformly
  to both physical and magic damage).

  The three damage riders are read from the combatant's precomputed
  `dragonology_level` (`Combat.RaceModifiers.dragonology_atk_rate/2`,
  `dragonology_matk_rate/2`, `dragonology_resist_rate/2`), applied directly
  in `Combat.DamageCalculator` and `Combat.MagicDamageCalculator` — the same
  precomputed-combatant-field pattern `AL_DEMONBANE`/`AL_DP` already use, since
  Aesir has no scripted `bonus2 bAddRace` equipment/card engine to source a
  status-effect-style modifier map from. This module contributes only
  `int_bonus/2`; it carries no other passive callback.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 284,
    name: :sa_dragonology,
    display_name: "Dragonology",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def int_bonus(level, _ctx), do: div(level + 1, 2)
end
