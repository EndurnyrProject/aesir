defmodule Aesir.ZoneServer.Mmo.JobManagement.Job do
  use TypedStruct

  typedstruct enforce: true, module: Experience do
    field :level, non_neg_integer()
    field :exp, non_neg_integer()
  end

  typedstruct module: BaseHp do
    field :level, non_neg_integer()
    field :hp, non_neg_integer()
  end

  typedstruct module: BaseSp do
    field :level, non_neg_integer()
    field :sp, non_neg_integer()
  end

  typedstruct module: BaseAp do
    field :level, non_neg_integer()
    field :ap, non_neg_integer()
  end

  typedstruct module: BonusStats do
    field :level, non_neg_integer()
    field :str, non_neg_integer(), default: 0
    field :agi, non_neg_integer(), default: 0
    field :vit, non_neg_integer(), default: 0
    field :int, non_neg_integer(), default: 0
    field :dex, non_neg_integer(), default: 0
    field :luk, non_neg_integer(), default: 0
    field :pow, non_neg_integer(), default: 0
    field :sta, non_neg_integer(), default: 0
    field :wis, non_neg_integer(), default: 0
    field :spl, non_neg_integer(), default: 0
    field :con, non_neg_integer(), default: 0
    field :crt, non_neg_integer(), default: 0
  end

  typedstruct module: MaxStats do
    field :hp, non_neg_integer()
    field :sp, non_neg_integer()
    field :ap, non_neg_integer()
    field :str, non_neg_integer()
    field :agi, non_neg_integer()
    field :vit, non_neg_integer()
    field :int, non_neg_integer()
    field :dex, non_neg_integer()
    field :luk, non_neg_integer()
    field :pow, non_neg_integer()
    field :sta, non_neg_integer()
    field :wis, non_neg_integer()
    field :spl, non_neg_integer()
    field :con, non_neg_integer()
    field :crt, non_neg_integer()
  end

  typedstruct module: BaseAspd do
    field :fist, non_neg_integer()
    field :dagger, non_neg_integer()
    field :one_handed_sword, non_neg_integer()
    field :two_handed_sword, non_neg_integer()
    field :one_handed_spear, non_neg_integer()
    field :two_handed_spear, non_neg_integer()
    field :one_handed_axe, non_neg_integer()
    field :two_handed_axe, non_neg_integer()
    field :mace, non_neg_integer()
    field :two_handed_mace, non_neg_integer()
    field :staff, non_neg_integer()
    field :bow, non_neg_integer()
    field :knuckle, non_neg_integer()
    field :musical, non_neg_integer()
    field :whip, non_neg_integer()
    field :book, non_neg_integer()
    field :katar, non_neg_integer()
    field :revolver, non_neg_integer()
    field :rifle, non_neg_integer()
    field :gatling, non_neg_integer()
    field :shotgun, non_neg_integer()
    field :grenade, non_neg_integer()
    field :huuma, non_neg_integer()
    field :two_handed_staff, non_neg_integer()
    field :shield, non_neg_integer()
  end

  typedstruct do
    field :id, non_neg_integer()
    field :name, atom()

    field :base_ap, list(BaseAp.t())
    field :base_hp, list(BaseHp.t())
    field :base_sp, list(BaseSp.t())
    field :base_aspd, BaseAspd.t()

    field :hp_factor, non_neg_integer()
    field :hp_increase, non_neg_integer()
    field :sp_factor, non_neg_integer()
    field :sp_increase, non_neg_integer()
    field :ap_factor, non_neg_integer()
    field :ap_increase, non_neg_integer()

    field :bonus_stats, list(BonusStats.t())

    field :base_exp, list(Experience.t())
    field :job_exp, list(Experience.t())

    field :max_weight, non_neg_integer()
    field :max_base_level, non_neg_integer()
    field :max_job_level, non_neg_integer()
    field :max_stats, MaxStats.t()
  end
end
