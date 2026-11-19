defmodule Aesir.ZoneServer.Mmo.JobManagement.Job do
  @moduledoc """
  Struct describing a single job's static data.

  Dense per-level tables (`base_hp`, `base_sp`, `base_ap`, `base_exp`,
  `job_exp`, `bonus_stats`) are plain maps keyed by level, so a level lookup is
  a single `Map.fetch/2`. The data is loaded by `Aesir.ZoneServer.Mmo.JobManagement.Loader`
  and cached by `Aesir.ZoneServer.Mmo.JobManagement.Jobs`.
  """

  use TypedStruct

  alias __MODULE__.BaseAspd
  alias __MODULE__.BonusStats

  defmodule BonusStats do
    @moduledoc "Cumulative bonus stats granted up to a job level."

    use TypedStruct

    @typedoc "Bonus stats at `level`; `level` is nil only on the zero accumulator."
    typedstruct do
      field :level, pos_integer() | nil
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
  end

  defmodule BaseAspd do
    @moduledoc "Base attack delay per weapon type. A nil field means the job cannot use that weapon."

    use TypedStruct

    @typedoc "Base attack delay per weapon type."
    typedstruct do
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
  end

  @typedoc "Dense table keyed by level."
  @type level_table :: %{pos_integer() => non_neg_integer()}

  @typedoc "A job's static data."
  typedstruct do
    field :id, non_neg_integer(), enforce: true
    field :name, atom(), enforce: true
    field :base_hp, level_table(), default: %{}
    field :base_sp, level_table(), default: %{}
    field :base_ap, level_table(), default: %{}
    field :base_exp, level_table(), default: %{}
    field :job_exp, level_table(), default: %{}
    field :bonus_stats, %{pos_integer() => BonusStats.t()}, default: %{}
    field :base_aspd, BaseAspd.t()
    field :max_weight, non_neg_integer(), default: 0
    field :max_base_level, pos_integer(), default: 99
    field :max_job_level, pos_integer(), default: 99
  end
end
