defmodule Aesir.ZoneServer.Gm.Commands.ShowDelay do
  @moduledoc """
  `@showdelay` - turns the caller's act delay and cooldown refusal notices on
  or off; they start off. Available to every account group but the default
  Player and VIP groups (rAthena's stock `groups.yml` grants it from Super
  Player up). Delivery is `PlayerSession.toggle_show_delay/1` on the caller's
  own session.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.Commons.Auth
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @excluded_groups [0, 5]

  @impl true
  def name, do: "showdelay"

  @impl true
  def required_level, do: 0

  @impl true
  def execute(_args, ctx) do
    if Auth.get_account!(ctx.game_state.account_id).group_id in @excluded_groups do
      {:error, "Insufficient permission"}
    else
      PlayerSession.toggle_show_delay(self())
      {:ok, message(not ctx.game_state.show_delay)}
    end
  end

  defp message(true), do: "Skill delay failures are now shown."
  defp message(false), do: "Skill delay failures will not be shown."
end
