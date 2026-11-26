defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.SplendidSword do
  @moduledoc """
  Offers a cursed sword that can reveal the black key and Varmunt's Journal.

  ## Behavior

  - Requires four keys to approach the sword and obtain the black key.
  - Awards the journal when the tower quest is at the appropriate stage.

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
        map: "tha_t06",
        x: 204,
        y: 181,
        dir: 0,
        sprite: 111,
        name: "Splendid Sword",
        scope: :shared,
        unique_name: "Splendid Sword#tt5",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    if unclaimed?(ctx), do: specialeffect(ctx, :level99_4), else: ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if unclaimed?(ctx) do
      ctx =
        ctx
        |> mes("An old, worn sword hangs above the splendid table.")
        |> mes("It emits a gloomy aura.")
        |> next()

      if Enum.all?([7421, 7422, 7423, 7424], &(count_item(ctx, &1) > 0)) do
        approach_sword(ctx)
      else
        ctx
        |> mes("You strongly feel a cursed, sealed power from here,")
        |> mes("but it is hard to figure out what is causing it.")
        |> mes("You cannot approach it.")
        |> close()
      end
    else
      ctx
      |> mes("You have already released a seal using this sword.")
      |> mes("You've acquired everything you need from here.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp unclaimed?(ctx), do: count_item(ctx, 7425) == 0 and count_item(ctx, 7430) == 0

  defp approach_sword(ctx) do
    {ctx, choice} =
      ctx
      |> mes("As you approach, the keys in your pocket")
      |> mes("suddenly respond with a mysterious power.")
      |> specialeffect2(:absorbspirits)
      |> next()
      |> select(["Observe it.", "Ignore it."])

    if choice == 2 do
      ctx
      |> mes("^3355FFYou decide to leave")
      |> mes("the sword alone.^000000")
      |> close()
    else
      grasp_sword(ctx)
    end
  end

  defp grasp_sword(ctx) do
    {ctx, choice} =
      ctx
      |> mes("While you get closer and closer, the sword shakes with a loud noise.")
      |> mes("Your eyes keep getting drawn to the sword's hilt.")
      |> mes("Then you lose control of your hands, and they stretch forth to grasp the handle...")
      |> next()
      |> select([
        "Towards the blade of the sword",
        "Towards the hilt of the sword",
        "Towards the table"
      ])

    case choice do
      1 ->
        ctx
        |> mes("By an unknown calling you decide to grab the blade of the sword.")
        |> mes("Your hands get wounded and begin to bleed.")
        |> specialeffect2(:hit1)
        |> percent_heal(hp: -20, sp: 0)
        |> close()

      2 ->
        hold_sword(ctx)

      3 ->
        ctx
        |> mes("You stretch your hands to find something under the table, but there is nothing.")
        |> close()

      _ ->
        ctx
    end
  end

  defp hold_sword(ctx) do
    {ctx, choice} =
      ctx
      |> mes("By an unknown calling you decide to grab the hilt of the sword.")
      |> mes(
        "The mysterious power from the keys transfers to the sword, and it falls from the table."
      )
      |> next()
      |> mes("At the same time, a little hole appears on the table's surface.")
      |> mes("Now, you hold the sword and...")
      |> specialeffect(:exit2)
      |> next()
      |> select(["Strike the table", "Insert the sword into the hole", "Bring the sword safely"])

    case choice do
      1 ->
        ctx
        |> mes("You strike the table with the sword.")
        |> mes(
          "Numerous conflicting spells act upon it, and you can tell that you chose incorrectly."
        )
        |> mes("The sword automatically returns to the table, as it was before.")
        |> specialeffect(:hit1)
        |> specialeffect2(:hit1)
        |> percent_heal(hp: -20, sp: 0)
        |> close()

      2 ->
        obtain_key(ctx)

      3 ->
        ctx
        |> mes("When you lift the sword, you feel a shock from numerous conflicting spells.")
        |> mes("Right... stealing is the worst.")
        |> mes("The sword automatically returns to the table, as it was before.")
        |> close()

      _ ->
        ctx
    end
  end

  defp obtain_key(ctx) do
    ctx =
      ctx
      |> mes(
        "As you insert the sword, lightning flashes around it and black smoke rises from the hole."
      )
      |> mes("Slowly the smoke clears, and you see an object with a certain shape...")
      |> specialeffect(:changedark)
      |> next()
      |> mes(
        "^4d4dff All of a sudden, a Black Key appears from the smoke and you feel a great cursed power from it.^000000"
      )
      |> give_item(7425, 1)

    if get_char_var(ctx, :thana_tower, 0) == 8 do
      ctx
      |> next()
      |> mes(
        "A drawer had snapped open under the table while you picked up the key and observed it."
      )
      |> mes("You can see an old notebook inside the drawer.")
      |> next()
      |> mes("The notebook definitely looks like it contains an important message.")
      |> mes(
        "Maybe this notebook is the one that Rekenber wants to find, even with all the sacrifices."
      )
      |> next()
      |> mes("^4d4dffYou decide to show the notebook and the keys to Burled.")
      |> mes("You received Varmunt's Journal.^000000")
      |> set_char_var(:thana_tower, 9)
      |> changequest(7052, 7053)
      |> give_item(11011, 1)
      |> close()
    else
      close(ctx)
    end
  end
end
