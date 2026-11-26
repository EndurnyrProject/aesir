defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNiflheim.Kuzkahina do
  @moduledoc """
  A grumbling Niflheim shopkeeper who hands Piano Key questers a keyboard to throw away.

  ## Behavior

  - Players at the Kuzkahina step of either key route receive a Piano Keyboard and advance
    their route by two steps.
  - Anyone else only hears him complain about his store.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Evera
    - Lupus
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
        map: "nif_in",
        x: 31,
        y: 20,
        dir: 3,
        sprite: 794,
        name: "Kuzkahina",
        scope: :shared,
        unique_name: "Kuzkahina#nif"
      }
    ]

  @piano_keyboard 7184

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :nif_esc, 0) in [2, 3] do
      ctx =
        ctx
        |> complain()
        |> next()
        |> mes("[Kuzkahina]")
        |> mes("Hey you! Make yourself useful")
        |> mes("and throw this away when you leave.")

      ctx
      |> set_char_var(:nif_esc, get_char_var(ctx, :nif_esc, 0) + 2)
      |> give_item(@piano_keyboard, 1)
      |> next()
      |> mes("[Kuzkahina]")
      |> mes("Gosh, what's with this store?")
      |> mes("How did I end up hiring such useless employees...?")
      |> mes("*mumble mumble*")
      |> mes("*mumble mumble*")
      |> close()
    else
      ctx |> complain() |> close()
    end
  end

  defp complain(ctx) do
    ctx
    |> mes("[Kuzkahina]")
    |> mes("I don't understand")
    |> mes("why I can't make any")
    |> mes("money with this store...")
    |> mes("Even when I was alive")
    |> mes("I could never make any")
    |> mes("money with my businesses...")
  end
end
