defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.Hedrick do
  @moduledoc """
  Hedrick, a convent worker who receives his mother's letter during the Acolyte training quest.

  ## Behavior

  - On the second delivery step, takes the Mother's Letter, advances the quest and gives the
    player a Well Baked Cookie.
  - Otherwise only brags about his hard work.

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
    spawn: [
      %{map: "prt_monk", x: 28, y: 260, dir: 5, sprite: 50, name: "Hedrick", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Hedrick]")
      |> mes("^333333*Whew!*^000000")
      |> mes("Man I worked hard today!")
      |> mes("And so efficiently too!")
      |> mes("Awesome job as usual,")
      |> mes("Hedrick. You're number one!")

    if count_item(ctx, 7148) == 0 or get_char_var(ctx, :tu_acolyte01, 0) != 19 do
      close(ctx)
    else
      receive_letter(ctx)
    end
  end

  defp receive_letter(ctx) do
    ctx
    |> next()
    |> mes("[Hedrick]")
    |> mes("Oh...?")
    |> mes("Is this letter for me?")
    |> mes("I wonder who it's from.")
    |> mes("Ah, it's from my mom!")
    |> next()
    |> mes("[Hedrick]")
    |> mes("Whoa...!")
    |> mes("Holy cow!")
    |> mes("This letter is")
    |> mes("full of the energy")
    |> mes("of motherly love!")
    |> specialeffect(:steelbody)
    |> next()
    |> mes("[Hedrick]")
    |> mes("Thanks a lot!")
    |> mes("Here, why don't")
    |> mes("you have one of the")
    |> mes("cookies she sent me?")
    |> delitem(7148, 1)
    |> set_char_var(:tu_acolyte01, 20)
    |> give_item(538, 1)
    |> close()
  end
end
