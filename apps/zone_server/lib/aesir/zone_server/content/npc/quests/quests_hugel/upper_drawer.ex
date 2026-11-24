defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.UpperDrawer do
  @moduledoc """
  Contains Allen's medicines, reading material, and quest reward.

  ## Behavior

  - Reveals Allen's reading material or interrupts the search for medicine.
  - Awards the Old Blue Box and experience at the end of the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 370,
        y: 255,
        dir: 3,
        sprite: 139,
        name: "Upper Drawer",
        scope: :shared,
        unique_name: "Upper Drawer#First",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx), do: search_drawer(ctx)

  @impl true
  def on_talk(ctx), do: search_drawer(ctx)

  defp search_drawer(ctx) do
    ctx = set_local(ctx, :rand, Enum.random(1..7))
    stage = get_char_var(ctx, :hg_herb, 0)

    cond do
      stage < 5 ->
        ctx
        |> mes("^3355FFThere are several")
        |> mes("books and a few")
        |> mes("liquid medicines")
        |> mes("inside this drawer.^000000")
        |> close()

      stage in [5, 8] ->
        ctx =
          ctx
          |> mes("[Allen]")
          |> mes("Oh... Oh...")
          |> mes("Oooh... The pain")
          |> mes("is gone! It's a miracle!")
          |> mes("Maybe I'll just take the")
          |> mes("Withstander later...")
          |> set_char_var(:hg_herb, stage - 1)
          |> next()

        ctx = if stage == 5, do: set_local(ctx, :rand, Enum.random(1..7)), else: ctx

        case get_local(ctx, :rand, 0) do
          4 ->
            old_book(ctx)

          5 ->
            journal(ctx)

          _ ->
            ctx
            |> mes("[#{char_name(ctx, 0)}]")
            |> mes("Wh-what...?")
            |> mes("Do you really")
            |> mes("need that medicine?!")
            |> close()
        end

      stage in [6, 9] ->
        ctx

      stage == 12 ->
        ctx =
          ctx
          |> mes("^3355FFYou find an")
          |> mes("Old Blue Box deep")
          |> mes("inside the drawer.^000000")
          |> close()
          |> specialeffect(:cone)
          |> set_char_var(:hg_herb, 13)
          |> give_item(603, 1)

        ctx
        |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 5000, else: 50000), 0)
        |> completequest(8056)

      get_local(ctx, :rand, 0) > 3 ->
        old_book(ctx)

      true ->
        journal(ctx)
    end
  end

  defp old_book(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou find an old book")
      |> mes("inside the drawer.^000000")
      |> next()
      |> mes("[Welcome to Lighthalzen!]")
      |> mes("Author: Tupetso Iltekka")
      |> next()
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("(^333333I guess Allen used")
    |> mes("to live in Lighthalzen.")
    |> mes("I guess that's why he'd")
    |> mes("keep this old PR brochure...^000000)")
    |> close()
  end

  defp journal(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou find Allen's")
      |> mes("journal inside the")
      |> mes("drawer and quickly")
      |> mes("leaf through its pages.")
      |> mes("It's difficult to read since")
      |> mes("the pages are old and worn.^000000")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Let's see, let's see...")
    |> mes("Rekenber Corporation...")
    |> mes("Something about the Slums....")
    |> mes("Enormous funds... Experiments.")
    |> mes("Lab... Escape... Hugel... Um...")
    |> mes("Dr. Morriphen... Side effects?")
    |> close()
  end
end
