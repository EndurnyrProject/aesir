defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CloseConfine2 do
  @moduledoc """
  Close Confine's recipient root (SC_CLOSECONFINE2), shared by both modes.

  Ordinary starts link the caster's hold; loaded entries retain their values
  without creating another hold. A recipient cannot be held twice. Expiry or
  removal updates the caster link, while death alone preserves the status.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_closeconfine2,
    immunity: [:boss],
    no_dispel: true,
    no_clear_buff: false,
    no_save: true,
    remove_on_death: false,
    remove_on_map_change: true,
    prevented_by: [:sc_closeconfine2],
    properties: [:prevents_movement],
    flags: [:no_move],
    duration: 10_000,
    icon: :rg_cconfine_s

  alias Aesir.ZoneServer.Mmo.StatusEffect.CloseConfineLink
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec resolve_duration({atom(), integer()}, StatusEntry.t(), pos_integer()) ::
          {pos_integer(), StatusEntry.t()}
  def resolve_duration(_target, instance, duration),
    do: {duration, CloseConfineLink.initialize_recipient(instance)}

  @impl true
  @spec on_apply({atom(), integer()}, StatusEntry.t(), map()) ::
          {:ok, StatusEntry.t()} | {:error, atom()}
  def on_apply(_target, instance, %{loaded: true}), do: {:ok, instance}

  def on_apply(_target, instance, %{duration: duration}),
    do: CloseConfineLink.start_recipient(instance, duration)

  @impl true
  @spec on_expire({atom(), integer()}, StatusEntry.t(), map()) :: :ok
  def on_expire(_target, instance, _context), do: CloseConfineLink.end_recipient(instance)
end
