defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Hole127146 do
  @moduledoc """
  Crest device guarding Juperos security checkpoint 2-3.

  ## Behavior

  - Shows the device's cutin and describes its empty slot.
  - While the area is in use (an alarm or guard wave is running), it refuses to work.
  - Carrying any Crest Piece lets the player try one; only the matching piece fits.
  - The matching piece opens the checkpoint's warp portal, arms its alarm and shuts the
    device until its timer reopens it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
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
        map: "jupe_area2",
        x: 127,
        y: 146,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#hole#2-3"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @crest_pieces [7356, 7359, 7357, 7358]
  @crest_piece 7358
  @area_in_use "JupreArea2InUse"
  @device_image "3"
  @inserted_image "3-1"

  @impl true
  def on_event("OnStop_Timer", ctx), do: stopnpctimer(ctx)

  def on_event("OnTimer22500", ctx) do
    ctx
    |> stopnpctimer()
    |> enablenpc("#hole#2-3")
    |> disablenpc("Red Alarm#2-3")
  end

  @impl true
  def on_talk(ctx) do
    ctx = cutin(ctx, @device_image, 2)

    cond do
      area_in_use?(ctx) -> ctx |> describe_slot() |> close() |> cutin(@device_image, 255)
      Enum.any?(@crest_pieces, &(count_item(ctx, &1) > 0)) -> offer_crest_piece(ctx)
      true -> ctx |> describe_slot() |> close() |> cutin(@device_image, 255)
    end
  end

  defp offer_crest_piece(ctx) do
    {ctx, choice} =
      ctx
      |> describe_slot()
      |> next()
      |> select(["Insert a Crest Piece.", "Cancel."])

    case choice do
      1 -> insert_crest_piece(ctx)
      2 -> cancel(ctx)
      _ -> ctx
    end
  end

  defp insert_crest_piece(ctx) do
    if count_item(ctx, @crest_piece) > 0 do
      ctx =
        ctx
        |> mes("^3355FFYou take out your")
        |> mes("Crest Piece and place")
        |> mes("it into the slot where it")
        |> mes("happens to fit perfectly.^000000")
        |> specialeffect(:toprank)
        |> cutin(@inserted_image, 2)
        |> next()

      if area_in_use?(ctx), do: blocked(ctx), else: open_portal(ctx)
    else
      ctx
      |> mes("^3355FFUnfortunately, you're")
      |> mes("not carrying anything")
      |> mes("that might be able to fit")
      |> mes("into the slot and activate")
      |> mes("this mechanical device.^000000")
      |> close()
      |> cutin(@device_image, 255)
    end
  end

  defp blocked(ctx) do
    ctx
    |> mes("^3355FFNothing happens.")
    |> mes("Perhaps an alarm or")
    |> mes("some other safety measure")
    |> mes("was activated to keep the")
    |> mes("Crest Piece from activating")
    |> mes("this transportation device.")
    |> mes("You retrieve the Crest Piece.^000000")
    |> close()
    |> cutin(@inserted_image, 255)
  end

  defp open_portal(ctx) do
    ctx
    |> mes("^3355FFThe slot rotates and")
    |> mes("the Crest Piece moves as")
    |> mes("if it were turning a key. You")
    |> mes("feel a weak tremor as a Warp")
    |> mes("Portal to the other side is")
    |> mes("activated. You then retrieve")
    |> mes("your Crest Piece.^000000")
    |> initnpctimer()
    |> donpcevent("Warp#2-3::OnEnable")
    |> enablenpc("Red Alarm#2-3")
    |> disablenpc("#hole#2-3")
    |> close()
    |> cutin(@inserted_image, 255)
  end

  defp cancel(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hmmm...")
    |> mes("Do I have anything")
    |> mes("that might make this")
    |> mes("weird machine work?")
    |> close()
    |> cutin(@device_image, 255)
  end

  defp describe_slot(ctx) do
    ctx
    |> mes("^3355FFThis seems like")
    |> mes("some kind of device")
    |> mes("that will allow you to")
    |> mes("pass to the other side.")
    |> mes("There's a slot where you")
    |> mes("probably need to insert")
    |> mes("some kind of object...^000000")
  end

  defp area_in_use?(ctx), do: get_server_temp_var(ctx, @area_in_use, 0) == 1
end
