defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.ValkyrieWarp do
  @moduledoc """
  Controls access to the Valkyrie's realm.

  ## Behavior

  - Reacts to quest materials and consumes them to transport the player.
  - Allows later visits unless the player has been banished.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gef_fild07",
        x: 182,
        y: 241,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#Valkyrie Warp",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    touch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if ready?(ctx) do
      ctx
      |> mes("^6B8E23It seems that")
      |> mes("something in the")
      |> mes("vicinity is reacting")
      |> mes("with the Sobbing Starlight")
      |> mes("in your possession. Perhaps")
      |> mes("you can find it nearby...^000000")
      |> close()
    else
      touch(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ready?(ctx) do
    get_char_var(ctx, :sign_q, 0) == 80 and count_item(ctx, 907) > 3 and
      count_item(ctx, 953) > 11 and count_item(ctx, 7013) > 364
  end

  defp touch(ctx) do
    cond do
      ready?(ctx) ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("What the...?")
        |> mes("What's happening?!")
        |> specialeffect2(:beginspell6)
        |> next()
        |> mes("^3355FFFor some reason, in")
        |> mes("this particular spot, the")
        |> mes("Sobbing Starlight is reacting")
        |> mes("with the Resin, Stone Hearts")
        |> mes("and Coral Reefs that you're")
        |> mes("holding. All the objects are")
        |> mes("violently resonating...^000000")
        |> specialeffect2(:enhance)
        |> next()
        |> mes("^3355FFAll of a sudden these")
        |> mes("objects emit a bright flash")
        |> mes("of light that envelops your")
        |> mes("entire body, then you gently")
        |> mes("fall into unconsciousness...^000000")
        |> specialeffect2(:flasher)
        |> next()
        |> delitem(907, 4)
        |> delitem(953, 12)
        |> delitem(7013, 365)
        |> set_char_var(:sign_q, 81)
        |> warp("himinn", 49, 10)

      get_char_var(ctx, :sign_q, 0) == 203 ->
        ctx
        |> mes("^3355FFNothing seems to")
        |> mes("happen when you")
        |> mes("approach this area now.^000000")
        |> close()

      get_char_var(ctx, :sign_q, 0) > 80 ->
        warp(ctx, "himinn", 49, 10)

      true ->
        ctx
    end
  end
end
