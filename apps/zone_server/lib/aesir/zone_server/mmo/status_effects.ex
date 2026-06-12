defmodule Aesir.ZoneServer.Mmo.StatusEffects do
  @moduledoc """
  Registry of status effect implementations.

  Each entry is a module implementing `Aesir.ZoneServer.Mmo.StatusEffect.Definition`.
  New status effects are added by creating a module under
  `Aesir.ZoneServer.Mmo.StatusEffects` and listing it here.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffects

  @modules [
    StatusEffects.Angelus,
    StatusEffects.ArcaneCharge,
    StatusEffects.Aspersio,
    StatusEffects.Benedictio,
    StatusEffects.Bleeding,
    StatusEffects.Blessing,
    StatusEffects.Blind,
    StatusEffects.Cloaking,
    StatusEffects.Concentrate,
    StatusEffects.Confusion,
    StatusEffects.Curse,
    StatusEffects.DeadlyPoison,
    StatusEffects.DecreaseAgi,
    StatusEffects.EnchantPoison,
    StatusEffects.Endure,
    StatusEffects.Freeze,
    StatusEffects.Gloria,
    StatusEffects.Hiding,
    StatusEffects.Impositio,
    StatusEffects.IncreaseAgi,
    StatusEffects.Kyrie,
    StatusEffects.Magnificat,
    StatusEffects.Poison,
    StatusEffects.PoisonReact,
    StatusEffects.Provoke,
    StatusEffects.Quagmire,
    StatusEffects.SignumCrucis,
    StatusEffects.Silence,
    StatusEffects.Sleep,
    StatusEffects.SlowPoison,
    StatusEffects.Stone,
    StatusEffects.Stun,
    StatusEffects.Suffragium,
    StatusEffects.TwoHandQuicken
  ]

  @doc """
  Returns all status effect implementations.
  """
  @spec all() :: [module()]
  def all, do: @modules
end
