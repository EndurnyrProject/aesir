defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.WindmillOwner do
  @moduledoc """
  Mills supplies the delivery package requested by Cezu.

  ## Behavior

  - Checks carrying capacity before offering the package.
  - Hands over the package once and then complains about his assistant.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 366,
        y: 299,
        dir: 4,
        sprite: 46,
        name: "Windmill Owner",
        scope: :shared,
        unique_name: "Windmill Owner#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7488, 1}]) == 0 ->
        ctx
        |> mes("[Mills]")
        |> mes("Hey, you've got too much")
        |> mes("stuff on you right now. ")
        |> mes("Put your junk in Kafra Storage")
        |> mes("if you expect me to give you")
        |> mes("anything. That's why you came")
        |> mes("here to the miss, didn't you?")
        |> close()

      get_char_var(ctx, :KHToastGirlEnd, 0) < 1 ->
        ctx
        |> mes("[Mills]")
        |> mes("Hey, whaddya want?")
        |> mes("I'm pretty busy right")
        |> mes("now, so you mind coming")
        |> mes("back later? Then we'll talk.")
        |> close()

      get_char_var(ctx, :KHToastGirlEnd, 0) == 1 ->
        offer_delivery(ctx)

      get_char_var(ctx, :KHToastGirlEnd, 0) >= 2 ->
        ctx
        |> mes("[Mills]")
        |> mes("That Cutz is such")
        |> mes("a lazy rascal. The guy")
        |> mes("thinks he can fool around")
        |> mes("when he's on the clock...!")
        |> mes("Ah well, he knows I can't find")
        |> mes("a better assistant. He'll learn...")
        |> close()

      true ->
        ctx
    end
  end

  defp offer_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mills]")
      |> mes("Hey, whaddya want?")
      |> mes("You just happened to")
      |> mes("catch me at a good time,")
      |> mes("but if you need anything,")
      |> mes("you'd better spit it out quick")
      |> mes("before things get hectic again.")
      |> next()
      |> select(["I'm here for Cezu", "......"])

    case choice do
      1 ->
        ctx
        |> mes("[Mills]")
        |> mes("Oh, Cezu from the")
        |> mes("toast stand? Okay,")
        |> mes("I've got everything")
        |> mes("that kid needs right")
        |> mes("here. There's eggs inside,")
        |> mes("so be really careful with it.")
        |> mes("It's ready for you...")
        |> next()
        |> mes("[Mills]")
        |> mes("Kid's one of my regular")
        |> mes("customers, so you don't")
        |> mes("have to pay me, or run any")
        |> mes("extra errands on my end. Yeah,")
        |> mes("I know how other people treat")
        |> mes("you adventurers. Well, see ya.")
        |> give_item(7488, 1)
        |> set_char_var(:KHToastGirlEnd, 2)
        |> close()

      2 ->
        ctx
        |> mes("[Mills]")
        |> mes("......")
        |> mes("Um, okay, well, if")
        |> mes("you need something,")
        |> mes("just hollar, I guess.")
        |> mes("Cuts, Cutz where are you?")
        |> mes("You'd better not be goofing off!")
        |> close()

      _ ->
        ctx
    end
  end
end
