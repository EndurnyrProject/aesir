defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects do
  @moduledoc """
  Registry of status effect implementations.

  Each entry is a module implementing `Aesir.ZoneServer.Mmo.StatusEffect.Definition`.
  New status effects are added by creating a module under
  `Aesir.ZoneServer.Mmo.StatusEffect.Effects` and listing it here.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects

  @modules [
    Effects.Angelus,
    Effects.ArcaneCharge,
    Effects.Aspersio,
    Effects.Autoberserk,
    Effects.Benedictio,
    Effects.Bleeding,
    Effects.Blessing,
    Effects.Blind,
    Effects.Cloaking,
    Effects.Concentrate,
    Effects.Confusion,
    Effects.Curse,
    Effects.DeadlyPoison,
    Effects.DecreaseAgi,
    Effects.EnchantPoison,
    Effects.Endure,
    Effects.EnergyCoat,
    Effects.Freeze,
    Effects.Gloria,
    Effects.Hiding,
    Effects.Impositio,
    Effects.IncreaseAgi,
    Effects.Kyrie,
    Effects.Magnificat,
    Effects.Poison,
    Effects.PoisonReact,
    Effects.Provoke,
    Effects.Quagmire,
    Effects.Safetywall,
    Effects.SignumCrucis,
    Effects.Sight,
    Effects.Silence,
    Effects.Sleep,
    Effects.SlowPoison,
    Effects.Stone,
    Effects.Stun,
    Effects.Suffragium,
    Effects.TrickDead,
    Effects.TwoHandQuicken,
    Effects.WatkElement
  ]

  @doc """
  Returns all status effect implementations.
  """
  @spec all() :: [module()]
  def all, do: @modules
end
