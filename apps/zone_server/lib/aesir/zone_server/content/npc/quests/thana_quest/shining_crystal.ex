defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.ShiningCrystal do
  @moduledoc """
  Exchanges the red key for a red charm stone.

  ## Behavior

  - Reveals the charm stone when the matching key is carried.
  - Enables or disables the crystal through events.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tha_t08",
        x: 90,
        y: 153,
        dir: 0,
        sprite: 844,
        name: "Shining Crystal",
        scope: :shared,
        unique_name: "Shining Crystal#tt_r1"
      },
      %{
        map: "tha_t08",
        x: 90,
        y: 62,
        dir: 0,
        sprite: 844,
        name: "Shining Crystal",
        scope: :shared,
        unique_name: "Shining Crystal#tt_r2"
      },
      %{
        map: "tha_t08",
        x: 49,
        y: 59,
        dir: 0,
        sprite: 844,
        name: "Shining Crystal",
        scope: :shared,
        unique_name: "Shining Crystal#tt_r3"
      },
      %{
        map: "tha_t08",
        x: 49,
        y: 144,
        dir: 0,
        sprite: 844,
        name: "Shining Crystal",
        scope: :shared,
        unique_name: "Shining Crystal#tt_r4"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    disablenpc(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnEnable", ctx) do
    enablenpc(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7421) > 0 do
      ctx
      |> mes("The Crystal ball is emitting mysterious power.")
      |> next()
      |> mes("Beside the crystal ball, you find faded patterns marked on the floor.")
      |> mes("Looks like some kind of keyhole that needs to be inserted with something...")
      |> next()
      |> mes("The red key suddenly responds once you come close to the keyhole.")
      |> mes("You insert the key in the keyhole and it turns out to be a small gem.")
      |> next()
      |> mes("When you touch the gem which is dazzling red...")
      |> mes("You feel isolated and depressed deep inside your heart...")
      |> next()
      |> mes(
        "^4d4dffYou have found a Red Charm Stone that is concentrated with cruel fate and a deep darkness.^000000"
      )
      |> delitem(7421, 1)
      |> give_item(7426, 1)
      |> close()
    else
      ctx
      |> mes("The Crystal ball is emitting mysterious power.")
      |> mes("Something is definitely there inside... How do I get it to open?")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
