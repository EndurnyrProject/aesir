defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SealStatus.SignPost do
  @moduledoc """
  Sign post showing the state of the four God Item seals and the player's own seal progress.

  ## Behavior

  - Lists each server-wide seal as Unseen, Active, Appeared or Released from its counter and the
    seal thresholds.
  - Lists whether the player has completed the Sleipnir, Megingjard, Brisingamen and Mjolnir
    seal quests.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 113,
        y: 294,
        dir: 3,
        sprite: 837,
        name: "Sign Post",
        scope: :shared,
        unique_name: "Sign Post#god"
      }
    ]

  @seals ["Sleipnir", "Megingjard", "Brisingamen", "Mjolnir"]
  @completion [
    {:god_sl_1, 51, "Sleipnir"},
    {:god_eremes, 28, "Megingjard"},
    {:god_brising, 50, "Brisingamen"},
    {:god_mjo_0, 11, "Mjolnir"}
  ]

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "======== God Seal Status ========")

    ctx =
      @seals
      |> Enum.with_index(1)
      |> Enum.reduce(ctx, fn {seal, index}, ctx ->
        mes(ctx, "#{seal} Seal: #{seal_status(ctx, getd(ctx, "$God#{index}"))}")
      end)
      |> mes(" ")
      |> mes("======= Your Seal Status ========")

    @completion
    |> Enum.reduce(ctx, fn {var, required, seal}, ctx ->
      if get_char_var(ctx, var, 0) < required do
        mes(ctx, "^ff0000#{seal} Seal: Not Completed^000000")
      else
        mes(ctx, "^00ff00#{seal} Seal: Completed^000000")
      end
    end)
    |> close()
  end

  defp seal_status(ctx, counter) do
    cond do
      counter == 0 -> "Unseen"
      counter < get_server_temp_var(ctx, "god_check1", 0) -> "Active"
      counter < get_server_temp_var(ctx, "god_check2", 0) -> "Appeared"
      true -> "Released"
    end
  end
end
