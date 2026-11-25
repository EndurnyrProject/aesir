defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Desk do
  @moduledoc """
  A cluttered desk conceals a stick for the cube room puzzle.

  ## Behavior

  - Finds a short stick or combines it with another to make a long stick.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_cube",
        x: 234,
        y: 200,
        dir: 0,
        sprite: 111,
        name: "Desk",
        scope: :shared,
        unique_name: "Desk#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_secret02, 0)

    cond do
      stage < 2 -> search_initial_desk(ctx, stage)
      stage == 2 -> search_desk_with_stick(ctx)
      true -> search_desk_after_sticks(ctx)
    end
  end

  defp search_initial_desk(ctx, stage) do
    {ctx, choice} = describe_initial_desk(ctx)

    case choice do
      1 -> documents(ctx)
      2 -> under_initial_desk(ctx, stage)
      3 -> initial_drawer(ctx)
      _ -> ctx
    end
  end

  defp describe_initial_desk(ctx) do
    ctx
    |> mes("^3355FFYou've found")
    |> mes("a completely")
    |> mes("cluttered desk.^000000")
    |> next()
    |> select(["On the desk", "Under the desk", "Desk drawer"])
  end

  defp documents(ctx) do
    ctx
    |> mes("^3355FFVarious documents,")
    |> mes("books and lab equipment")
    |> mes("are scattered on the desk.")
    |> mes("But none of them seem")
    |> mes("all that useful right now.^000000")
    |> close()
  end

  defp under_initial_desk(ctx, stage) do
    ctx = if stage < 1, do: find_short_stick(ctx), else: already_found_stick(ctx)
    close(ctx)
  end

  defp find_short_stick(ctx) do
    ctx
    |> mes("^3355FFUnder this desk, of")
    |> mes("all conceivable places,")
    |> mes("you find a ^000000Short Stick^3355FF")
    |> mes("that you decide to keep.")
    |> mes("You never know when")
    |> mes("you'll need one of those.^000000")
    |> set_char_var(:lhz_secret02, 1)
  end

  defp already_found_stick(ctx) do
    ctx
    |> mes("^3355FFThis is where you")
    |> mes("found your ^000000Short Stick^3355FF.")
    |> mes("Sadly, there are no more")
    |> mes("hidden treasures for you to")
    |> mes("discover beneath this desk.^000000")
  end

  defp initial_drawer(ctx) do
    ctx
    |> mes("^3355FFThe desk drawer is")
    |> mes("locked and probably")
    |> mes("with good reason. After all,")
    |> mes("you just tried to invade this")
    |> mes("private and intimate space.^000000")
    |> close()
  end

  defp search_desk_with_stick(ctx) do
    {ctx, choice} = describe_desk_with_stick(ctx)

    case choice do
      1 -> read_magazine(ctx)
      2 -> combine_sticks(ctx)
      3 -> locked_drawer(ctx)
      _ -> ctx
    end
  end

  defp describe_desk_with_stick(ctx) do
    ctx
    |> mes("^3355FFYou're back at the")
    |> mes("messy desk which")
    |> mes("is probably used by")
    |> mes("a high ranking executive")
    |> mes("who has someone else")
    |> mes("do his desk tidying for him.^000000")
    |> next()
    |> select(["On the desk", "Under the desk", "Desk drawer"])
  end

  defp read_magazine(ctx) do
    ctx = rummage_desk(ctx)
    ctx = if sex(ctx) == 1, do: dancer_magazine(ctx), else: entertainment_magazine(ctx)
    close(ctx)
  end

  defp rummage_desk(ctx) do
    ctx
    |> mes("^3355FFAlas, no matter how much")
    |> mes("you rummage through it,")
    |> mes("the clutter on the desk")
    |> mes("proves to be useless to you.^000000")
    |> next()
  end

  defp dancer_magazine(ctx) do
    ctx
    |> mes("^3355FFAn issue of the")
    |> mes("Dancer magazine,")
    |> mes("''Harmonic Lick'' catches")
    |> mes("your eye, but you really")
    |> mes("shouldn't be interested")
    |> mes("in that publication just")
    |> mes("because of the pictures.^000000")
  end

  defp entertainment_magazine(ctx) do
    ctx
    |> mes("^3355FFAn issue of the female")
    |> mes("entertainment magazine,")
    |> mes("''Magnum Break'' catches")
    |> mes("your eye, but adventurers")
    |> mes("have no time to look at")
    |> mes("pictures of beautiful men.^000000")
  end

  defp combine_sticks(ctx) do
    ctx
    |> mes("^3355FFUnder the desk, you")
    |> mes("discover another Short")
    |> mes("Stick which happens to")
    |> mes("fit perfectly into the other")
    |> mes("Short Stick you found earlier.")
    |> next()
    |> mes("^3355FFYou combine the two")
    |> mes("lesser sticks to create")
    |> mes("a stick that is superior")
    |> mes("to the sum of its parts.")
    |> mes("You are now the proud")
    |> mes("bearer of a ^000000Long Stick^3355FF.^000000")
    |> set_char_var(:lhz_secret02, 3)
    |> close()
  end

  defp locked_drawer(ctx) do
    ctx
    |> mes("^3355FFThis desk drawer is")
    |> mes("locked shut and probably")
    |> mes("always will be. It's likely")
    |> mes("that nothing really valuable")
    |> mes("is inside, aside from perhaps")
    |> mes("a hip flask or a candy stash.")
    |> close()
  end

  defp search_desk_after_sticks(ctx) do
    {ctx, choice} = describe_desk_after_sticks(ctx)

    case choice do
      1 -> newspaper(ctx)
      2 -> empty_under_desk(ctx)
      3 -> secure_drawer(ctx)
      _ -> ctx
    end
  end

  defp describe_desk_after_sticks(ctx) do
    ctx
    |> mes("^3355FFThis desk is cluttered")
    |> mes("with all sorts of random")
    |> mes("objects, but such is its")
    |> mes("destiny as office equipment.^000000")
    |> next()
    |> select(["On the desk", "Under the desk", "Desk drawer"])
  end

  defp newspaper(ctx) do
    ctx
    |> mes("^3355FFAlas, no matter how much")
    |> mes("you rummage through it,")
    |> mes("the clutter on the desk")
    |> mes("proves to be useless to you.^000000")
    |> next()
    |> mes("^3355FFThere's part of a newspaper")
    |> mes("here, but it's only the Comics")
    |> mes("section which, of course, isn't")
    |> mes("informative enough for world")
    |> mes("savvy adventurers like you.^000000")
    |> close()
  end

  defp empty_under_desk(ctx) do
    ctx
    |> mes("^3355FFThis is where you found")
    |> mes("one of two Short Sticks")
    |> mes("to make your ^000000Long Stick^3355FF.")
    |> mes("There isn't anything else")
    |> mes("under here, so it's impossible")
    |> mes("to make your stick any longer.^000000")
    |> close()
  end

  defp secure_drawer(ctx) do
    ctx
    |> mes("^3355FFThis desk drawer is")
    |> mes("locked very securely.")
    |> mes("The owner of this desk")
    |> mes("was wise to provide a")
    |> mes("measure of drawer security.")
    |> mes("But why put sticks under the")
    |> mes("desk? This is most curious...^000000")
    |> close()
  end
end
