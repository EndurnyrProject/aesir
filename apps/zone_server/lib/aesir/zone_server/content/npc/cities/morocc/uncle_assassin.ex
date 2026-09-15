defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.UncleAssassin do
  @moduledoc """
  Explains the Assassin clan’s principles and practices.

  ## Behavior

  - Offers information about the Assassin clan or its avoidance of strong smells.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild16",
        x: 199,
        y: 212,
        dir: 4,
        sprite: 55,
        name: " Uncle Assassin",
        scope: :shared,
        unique_name: " Uncle Assassin#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hashisid]")
      |> mes("...Assassins are trained")
      |> mes("to approach their enemies stealthily,")
      |> mes(" as well as")
      |> mes("to shroud their intent.")
      |> mes("For this purpose,")
      |> mes("we never")
      |> mes("look our targets in the eye.")
      |> next()
      |> select(["Notion of Assassin", "Quit Conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[Hashisid]")
        |> mes("Well, then..")
        |> mes("I'll tell you what it is!")
        |> mes("Assassins ..")
        |> mes("may be commonly known as")
        |> mes("infiltrators and murderers")
        |> mes("who kill without remorse.")
        |> next()
        |> mes("[Hashisid]")
        |> mes("In actuality,")
        |> mes("the Assassin clan")
        |> mes("is forbidden to harm innocent people,")
        |> mes("or at least,")
        |> mes("not without good reason")
        |> next()
        |> mes("[Hashisid]")
        |> mes("Our true directive is to assassinate evil creatures,")
        |> mes("and to use our stealth to gather intelligence")
        |> mes("for the good of all Rune-Midgarts.")
        |> close()

      2 ->
        ctx
        |> mes("[Hashisid]")
        |> mes("Once upon a time,")
        |> mes("our ancestors would")
        |> mes("smoke tobacco called 'Hashish'")
        |> mes("before performing their duties.")
        |> mes("However, we no longer do so,")
        |> mes("since insect or animal monsters are")
        |> mes("very sensitive to the smell.")
        |> next()
        |> mes("[Hashisid]")
        |> mes("We strictly prohibit")
        |> mes("smoking or eating")
        |> mes("anything that has")
        |> mes("strong smell...")
        |> mes("If you ever,")
        |> mes("try eating those")
        |> mes("smelly garlic bread with spices,")
        |> next()
        |> mes("[Hashisid]")
        |> mes("and try hiding against")
        |> mes("those wild boars or wolves,")
        |> mes("believe me,")
        |> mes("you'll be ripped in pieces.")
        |> close()

      _ ->
        ctx
    end
  end
end
