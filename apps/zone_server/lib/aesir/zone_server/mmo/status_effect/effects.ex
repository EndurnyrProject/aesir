defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects do
  @moduledoc """
  Registry of status effect implementations.

  Each entry is a module implementing `Aesir.ZoneServer.Mmo.StatusEffect.Definition`.
  New status effects are added by creating a module under
  `Aesir.ZoneServer.Mmo.StatusEffect.Effects` and listing it here.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects

  @modules [
    Effects.AgiFood,
    Effects.Almighty,
    Effects.Angelus,
    Effects.ArcaneCharge,
    Effects.Aspersio,
    Effects.Autoberserk,
    Effects.BatkFood,
    Effects.Benedictio,
    Effects.Bleeding,
    Effects.Blessing,
    Effects.Blind,
    Effects.Cloaking,
    Effects.Concentrate,
    Effects.Confusion,
    Effects.CriFood,
    Effects.Curse,
    Effects.DeadlyPoison,
    Effects.DecreaseAgi,
    Effects.DexFood,
    Effects.EnchantPoison,
    Effects.Endure,
    Effects.EnergyCoat,
    Effects.FleeFood,
    Effects.FoodAgiCash,
    Effects.FoodDexCash,
    Effects.FoodIntCash,
    Effects.FoodLukCash,
    Effects.FoodStrCash,
    Effects.FoodVitCash,
    Effects.Freeze,
    Effects.Gloria,
    Effects.Hiding,
    Effects.HitFood,
    Effects.Impositio,
    Effects.IncAllStatus,
    Effects.IncDex,
    Effects.IncInt,
    Effects.IncLuk,
    Effects.IncStr,
    Effects.IncreaseAgi,
    Effects.InfinityDrink,
    Effects.IntFood,
    Effects.IntScroll,
    Effects.Kyrie,
    Effects.LexAeterna,
    Effects.Loud,
    Effects.LukFood,
    Effects.Magnificat,
    Effects.MatkFood,
    Effects.Pneuma,
    Effects.PoemBragi,
    Effects.Poison,
    Effects.PoisonReact,
    Effects.Provoke,
    Effects.PushCart,
    Effects.Quagmire,
    Effects.Ruwach,
    Effects.Safetywall,
    Effects.SignumCrucis,
    Effects.Sight,
    Effects.Silence,
    Effects.Sleep,
    Effects.SlowPoison,
    Effects.Stone,
    Effects.StrFood,
    Effects.StrScroll,
    Effects.Stun,
    Effects.Suffragium,
    Effects.TrickDead,
    Effects.TwoHandQuicken,
    Effects.UltimateCook,
    Effects.VitFood,
    Effects.WatkElement,
    Effects.WatkFood
  ]

  @doc """
  Returns all status effect implementations.
  """
  @spec all() :: [module()]
  def all, do: @modules
end
