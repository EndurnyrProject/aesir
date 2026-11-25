defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.BrokenMachine do
  @moduledoc """
  A broken machine conceals a strange rock.

  ## Behavior

  - Allows the player to recover the rock during the investigation.

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
        map: "lhz_dun02",
        x: 282,
        y: 278,
        dir: 0,
        sprite: 111,
        name: "Broken Machine",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7346, 1}]) != 1 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :lhz_boss, 0) == 6 ->
        investigate(ctx)

      true ->
        ctx
        |> mes("^3355FFThere are several")
        |> mes("broken machines lying")
        |> mes("around that pretty much")
        |> mes("seem completely useless.^000000")
        |> close()
    end
  end

  defp investigate(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere are several")
      |> mes("broken machines lying")
      |> mes("around that pretty much")
      |> mes("seem completely useless.")
      |> mes("However, you catch the")
      |> mes("glimmer of a dim light")
      |> mes("amongst the scrap metal.^000000")
      |> next()
      |> select(["Investigate it.", "Ignore it."])

    case choice do
      1 ->
        inspect_rock(ctx)

      2 ->
        ctx
        |> mes("^3355FFWhat can possibly")
        |> mes("be of value in this")
        |> mes("pile of useless junk?^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp inspect_rock(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFAfter digging through")
      |> mes("the discarded machinery,")
      |> mes("you find a strange rock that")
      |> mes("is about as large as your fist")
      |> mes("and shimmers with a faint glow.^000000")
      |> next()
      |> select(["This might be important.", "This doesn't seem useful."])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFThis weird rock")
        |> mes("might be just the")
        |> mes("thing that ^000000Ghalstein^3355FF")
        |> mes("sent you here to find.")
        |> mes("He was probably right")
        |> mes("not to describe it to you.")
        |> mes("Words alone aren't enough...^000000")
        |> set_char_var(:lhz_boss, 7)
        |> give_item(7346, 1)
        |> close()

      2 ->
        ctx
        |> mes("^3355FFJust because this rock")
        |> mes("looks funny doesn't make")
        |> mes("it any more special than")
        |> mes("the countless number of")
        |> mes("rocks you've seen in")
        |> mes("your entire lifetime.^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
