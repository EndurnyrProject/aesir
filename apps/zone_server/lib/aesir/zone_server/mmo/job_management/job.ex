defmodule Aesir.ZoneServer.Mmo.JobManagement.Job do
  @moduledoc """
  Struct describing a single job's static data.

  Dense per-level tables (`base_hp`, `base_sp`, `base_ap`, `base_exp`,
  `job_exp`, `bonus_stats`) are plain maps keyed by level, so a level lookup is
  a single `Map.fetch/2`. The data is built by the generated job modules under
  `Aesir.ZoneServer.Mmo.JobManagement.Jobs` and lives in the BEAM constant pool.
  """

  # Per-level bonus stats granted at a job level.
  defmodule BonusStats do
    @moduledoc false

    defstruct level: nil,
              str: 0,
              agi: 0,
              vit: 0,
              int: 0,
              dex: 0,
              luk: 0,
              pow: 0,
              sta: 0,
              wis: 0,
              spl: 0,
              con: 0,
              crt: 0

    @type t() :: %__MODULE__{
            level: non_neg_integer() | nil,
            str: non_neg_integer(),
            agi: non_neg_integer(),
            vit: non_neg_integer(),
            int: non_neg_integer(),
            dex: non_neg_integer(),
            luk: non_neg_integer(),
            pow: non_neg_integer(),
            sta: non_neg_integer(),
            wis: non_neg_integer(),
            spl: non_neg_integer(),
            con: non_neg_integer(),
            crt: non_neg_integer()
          }
  end

  # Job-wide stat caps. Currently unused (kept nil), retained for shape.
  defmodule MaxStats do
    @moduledoc false

    defstruct [
      :hp,
      :sp,
      :ap,
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk,
      :pow,
      :sta,
      :wis,
      :spl,
      :con,
      :crt
    ]

    @type t() :: %__MODULE__{
            hp: non_neg_integer() | nil,
            sp: non_neg_integer() | nil,
            ap: non_neg_integer() | nil,
            str: non_neg_integer() | nil,
            agi: non_neg_integer() | nil,
            vit: non_neg_integer() | nil,
            int: non_neg_integer() | nil,
            dex: non_neg_integer() | nil,
            luk: non_neg_integer() | nil,
            pow: non_neg_integer() | nil,
            sta: non_neg_integer() | nil,
            wis: non_neg_integer() | nil,
            spl: non_neg_integer() | nil,
            con: non_neg_integer() | nil,
            crt: non_neg_integer() | nil
          }
  end

  # Base attack speed per weapon type. A nil field means the job cannot use that weapon.
  defmodule BaseAspd do
    @moduledoc false

    defstruct [
      :fist,
      :dagger,
      :one_handed_sword,
      :two_handed_sword,
      :one_handed_spear,
      :two_handed_spear,
      :one_handed_axe,
      :two_handed_axe,
      :mace,
      :two_handed_mace,
      :staff,
      :bow,
      :knuckle,
      :musical,
      :whip,
      :book,
      :katar,
      :revolver,
      :rifle,
      :gatling,
      :shotgun,
      :grenade,
      :huuma,
      :two_handed_staff,
      :shield
    ]

    @type t() :: %__MODULE__{
            fist: non_neg_integer() | nil,
            dagger: non_neg_integer() | nil,
            one_handed_sword: non_neg_integer() | nil,
            two_handed_sword: non_neg_integer() | nil,
            one_handed_spear: non_neg_integer() | nil,
            two_handed_spear: non_neg_integer() | nil,
            one_handed_axe: non_neg_integer() | nil,
            two_handed_axe: non_neg_integer() | nil,
            mace: non_neg_integer() | nil,
            two_handed_mace: non_neg_integer() | nil,
            staff: non_neg_integer() | nil,
            bow: non_neg_integer() | nil,
            knuckle: non_neg_integer() | nil,
            musical: non_neg_integer() | nil,
            whip: non_neg_integer() | nil,
            book: non_neg_integer() | nil,
            katar: non_neg_integer() | nil,
            revolver: non_neg_integer() | nil,
            rifle: non_neg_integer() | nil,
            gatling: non_neg_integer() | nil,
            shotgun: non_neg_integer() | nil,
            grenade: non_neg_integer() | nil,
            huuma: non_neg_integer() | nil,
            two_handed_staff: non_neg_integer() | nil,
            shield: non_neg_integer() | nil
          }
  end

  @typedoc "Dense table keyed by level."
  @type level_table :: %{non_neg_integer() => non_neg_integer()}

  defstruct id: nil,
            name: nil,
            base_hp: %{},
            base_sp: %{},
            base_ap: %{},
            base_exp: %{},
            job_exp: %{},
            bonus_stats: %{},
            base_aspd: nil,
            hp_factor: 0,
            hp_increase: 0,
            sp_factor: 0,
            sp_increase: 0,
            ap_factor: 0,
            ap_increase: 0,
            max_weight: 0,
            max_base_level: 99,
            max_job_level: 99,
            max_stats: nil

  @type t() :: %__MODULE__{
          id: non_neg_integer() | nil,
          name: atom() | nil,
          base_hp: level_table(),
          base_sp: level_table(),
          base_ap: level_table(),
          base_exp: level_table(),
          job_exp: level_table(),
          bonus_stats: %{non_neg_integer() => BonusStats.t()},
          base_aspd: BaseAspd.t() | nil,
          hp_factor: non_neg_integer(),
          hp_increase: non_neg_integer(),
          sp_factor: non_neg_integer(),
          sp_increase: non_neg_integer(),
          ap_factor: non_neg_integer(),
          ap_increase: non_neg_integer(),
          max_weight: non_neg_integer(),
          max_base_level: non_neg_integer(),
          max_job_level: non_neg_integer(),
          max_stats: MaxStats.t() | nil
        }
end
