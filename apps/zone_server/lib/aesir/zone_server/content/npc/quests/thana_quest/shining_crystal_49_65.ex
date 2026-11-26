defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.ShiningCrystal4965 do
  @moduledoc """
  Exchanges the blue key for a blue charm stone.

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
        x: 49,
        y: 65,
        dir: 0,
        sprite: 844,
        name: "Shining Crystal",
        scope: :shared,
        unique_name: "Shining Crystal#tt_b1"
      },
      %{
        map: "tha_t08",
        x: 49,
        y: 150,
        dir: 0,
        sprite: 844,
        name: "Shining Crystal",
        scope: :shared,
        unique_name: "Shining Crystal#tt_b2"
      },
      %{
        map: "tha_t08",
        x: 90,
        y: 147,
        dir: 0,
        sprite: 844,
        name: "Shining Crystal",
        scope: :shared,
        unique_name: "Shining Crystal#tt_b3"
      },
      %{
        map: "tha_t08",
        x: 90,
        y: 56,
        dir: 0,
        sprite: 844,
        name: "Shining Crystal",
        scope: :shared,
        unique_name: "Shining Crystal#tt_b4"
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
    if count_item(ctx, 7423) > 0 do
      ctx
      |> mes("The Crystal ball is emitting mysterious power.")
      |> next()
      |> mes("Beside the crystal ball, you find faded patterns marked on the floor.")
      |> mes("Looks like some kind of keyhole that needs to be inserted with something...")
      |> next()
      |> mes("The blue key suddenly responds once you come close to the keyhole.")
      |> mes("You insert the key in the keyhole and it turns out to be a small gem.")
      |> next()
      |> mes("When you touch the gem which is dazzling blue....")
      |> mes(
        "Someone's sobbing comes into your ears as you smell blood on the wind and suddenly you become angry."
      )
      |> next()
      |> mes(
        "^4d4dffYou have found a Blue Charm Stone that is concentrated with grudge and mysterious power.^000000"
      )
      |> delitem(7423, 1)
      |> give_item(7428, 1)
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
