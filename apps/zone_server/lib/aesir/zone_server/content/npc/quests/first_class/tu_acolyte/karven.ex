defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.Karven do
  @moduledoc """
  Priest Karven, who prays for the departed and receives his sister's letter during the
  Acolyte training quest.

  ## Behavior

  - On the fourth delivery step, takes the Sister's Letter and advances the quest.
  - Otherwise only offers a short prayer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "monk_in", x: 103, y: 176, dir: 7, sprite: 60, name: "Karven", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Karven]")
      |> mes("May you rest")

    if get_char_var(ctx, :tu_acolyte01, 0) == 21 and Rathena.truthy?(count_item(ctx, 7183)) do
      receive_letter(ctx)
    else
      ctx
      |> mes("rest in peace...")
      |> close()
    end
  end

  defp receive_letter(ctx) do
    ctx
    |> delitem(7183, 1)
    |> set_char_var(:tu_acolyte01, 22)
    |> mes("in peace forever...")
    |> next()
    |> mes("[Karven]")
    |> mes("I'm saying prayers")
    |> mes("for the recently departed.")
    |> mes("If it's not urgent, please")
    |> mes("come again at another time.")
    |> next()
    |> mes("[Karven]")
    |> mes("A letter?")
    |> mes("Oh. It must be from")
    |> mes("my younger sister.")
    |> mes("What could she want")
    |> mes("this time?")
    |> next()
    |> mes("[Karven]")
    |> mes("I hope she realizes")
    |> mes("the word of God and returns")
    |> mes("to living a good life once")
    |> mes("again. Thank you very much.")
    |> close()
  end
end
