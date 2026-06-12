defmodule Aesir.ZoneServer.Mmo.JobManagement.Job do
  @moduledoc """
  Struct describing a single job's static data.

  Dense per-level tables (`base_hp`, `base_sp`, `base_ap`, `base_exp`,
  `job_exp`, `bonus_stats`) are plain maps keyed by level, so a level lookup is
  a single `Map.fetch/2`. The data is built by the generated job modules under
  `Aesir.ZoneServer.Mmo.JobManagement.Jobs` and lives in the BEAM constant pool.
  """
  use TypedStruct

  # Per-level bonus stats granted at a job level.
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

  # Job-wide stat caps. Currently unused (kept nil), retained for shape.
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

  # Base attack speed per weapon type. A nil field means the job cannot use that weapon.
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

  @typedoc "Dense table keyed by level."
  @type level_table :: %{non_neg_integer() => non_neg_integer()}

  typedstruct do
    field :id, non_neg_integer()
    field :name, atom()

    field :base_hp, level_table(), default: %{}
    field :base_sp, level_table(), default: %{}
    field :base_ap, level_table(), default: %{}
    field :base_exp, level_table(), default: %{}
    field :job_exp, level_table(), default: %{}
    field :bonus_stats, %{non_neg_integer() => BonusStats.t()}, default: %{}

    field :base_aspd, BaseAspd.t()

    field :hp_factor, non_neg_integer(), default: 0
    field :hp_increase, non_neg_integer(), default: 0
    field :sp_factor, non_neg_integer(), default: 0
    field :sp_increase, non_neg_integer(), default: 0
    field :ap_factor, non_neg_integer(), default: 0
    field :ap_increase, non_neg_integer(), default: 0

    field :max_weight, non_neg_integer(), default: 0
    field :max_base_level, non_neg_integer(), default: 99
    field :max_job_level, non_neg_integer(), default: 99
    field :max_stats, MaxStats.t()
  end
end
