defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.MrIbanoff98110 do
  @moduledoc """
  Mr. Ibanoff guides travelers aboard his ship.

  ## Behavior

  - He directs the rudder, responds to monsters, and brings travelers to the island.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_ship",
        x: 98,
        y: 110,
        dir: 3,
        sprite: 964,
        name: "Mr. Ibanoff",
        scope: :shared,
        unique_name: "Mr. Ibanoff#npc2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :mos_whale_edq, 0)

    cond do
      stage == 4 -> first_voyage(ctx)
      stage == 5 -> hold_east(ctx)
      stage in [6, 21] -> north_current(ctx, stage)
      Rathena.truthy?(get_server_temp_var(ctx, "mos1_edq", 0)) -> monsters(ctx)
      stage == 20 -> hold_east(ctx)
      stage in [7, 22] -> hold_north(ctx)
      stage in [8, 10] -> direction_change(ctx, [3, 91, 92, 93, 94])
      stage in 91..94 -> direction_reminder(ctx, stage - 91)
      stage == 11 -> sighting(ctx)
      stage == 12 -> search_deck(ctx)
      stage == 19 -> second_voyage(ctx)
      stage in [23, 25] -> direction_change(ctx, [5, 241, 242, 243, 244])
      stage in 241..244 -> direction_reminder(ctx, stage - 241)
      stage == 26 -> land_on_island(ctx)
      true -> send_ashore(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp first_voyage(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("What a time for sailing!")
      |> mes("The wind of the sea is so cool.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You didn't have to accompany me")
      |> mes("through this dangerous sailing...")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Such as I am, I know the")
      |> mes("sea a lot better than you!")
      |> mes("And this ship has been my")
      |> mes("friend through all my life!")
      |> mes("I wouldn't abandon a friend.")
      |> mes("Would you? ~")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("I will order you where to go, by")
      |> mes("watching the seas.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("You just adjust the direction of")
      |> mes("the rudder by following my orders.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("At first, hold the rudder to go")
      |> mes("forward, to the east.")
      |> set_char_var(:mos_whale_edq, 5)

    ctx =
      if Rathena.truthy?(isbegin_quest(ctx, 18106)) do
        changequest(ctx, 18106, 18107)
      else
        ctx
      end

    close(ctx)
  end

  defp hold_east(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("Keep the direction by holding the")
    |> mes("rudder to move forward to the")
    |> mes("East.")
    |> close()
  end

  defp north_current(ctx, stage) do
    ctx =
      set_local(
        ctx,
        :r,
        if(stage == 21, do: 3, else: 4)
      )

    if Enum.random(1..get_local(ctx, :r, 0)) == 3 do
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Hm. The sea currents have changed.")
      |> mes("Adjust the rudder forward to the")
      |> mes("North, to follow the currents.")
      |> set_char_var(:mos_whale_edq, get_char_var(ctx, :mos_whale_edq, 0) + 1)
      |> close()
    else
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Nothing yet... Nothing has changed")
      |> mes("in the flow of water. There is")
      |> mes("nothing to note...")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("We had better keep sailing on this")
      |> mes("heading for now.")
      |> close()
    end
  end

  defp monsters(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("We must first repulse the")
    |> mes("monsters!")
    |> close()
  end

  defp hold_north(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("Hey!")
    |> mes("Did you not hear me?")
    |> mes("Change the rudder forward to the")
    |> mes("North, and follow the currents!")
    |> close()
  end

  defp direction_change(ctx, args) do
    {ctx, _} = scoped_call(ctx, args, &choose_direction/2)
    ctx
  end

  defp direction_reminder(ctx, direction) do
    {ctx, _} = scoped_call(ctx, [direction], &remind_direction/2)
    ctx
  end

  defp sighting(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Look... Beyond the sea!")
      |> mes("Do you see something moving")
      |> mes("mysteriously?")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Heheh... What is...")
      |> mes("that... Hey! You...")
      |> mes("Go around the deck to look more")
      |> mes("carefully! Go!")
      |> set_char_var(:mos_whale_edq, 12)

    ctx =
      if Rathena.truthy?(isbegin_quest(ctx, 18107)) do
        changequest(ctx, 18107, 18108)
      else
        ctx
      end

    ctx |> donpcevent("#findship::OnEnable") |> close()
  end

  defp search_deck(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("What are you doing...? Go around")
    |> mes("the deck to look more carefully!")
    |> mes("Go!")
    |> donpcevent("#findship::OnEnable")
    |> close()
  end

  defp second_voyage(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("This time, I hope to find that")
      |> mes("whale island again without any")
      |> mes("incidents...")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("The method is the same as before.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("I will order you where to go, by")
      |> mes("watching the seas.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("You just adjust the direction of")
      |> mes("the rudder by following my orders.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("At first, hold the rudder to go")
      |> mes("forward, to the east.")
      |> set_char_var(:mos_whale_edq, 20)

    ctx =
      if Rathena.truthy?(isbegin_quest(ctx, 18114)) do
        changequest(ctx, 18114, 18115)
      else
        ctx
      end

    close(ctx)
  end

  defp land_on_island(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Look there!")
      |> mes("There is a moving island!")
      |> mes("We have done well!")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Oh...my...")
      |> mes("It really is there...")
      |> mes("A whale! It's unbelievable!")
      |> mes("It is as true as that...")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("I feel I can go anywhere with you!")
      |> mes("Even through impossible things!")
      |> mes("Haha! You are a friend who brings")
      |> mes("good luck.")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Okay, now that you have landed on")
      |> mes("the island, I have to go back...")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("If another wave crashes against")
      |> mes("this boat, I feel she might break")
      |> mes("into pieces!")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Good luck. I hope you")
      |> mes("can return without problems.")
      |> mes("I will pray for you.")
      |> mes("See you next time.")
      |> set_char_var(:mos_whale_edq, 30)
      |> close2()
      |> warp("mosk_fild01", 93, 94)

    if Rathena.truthy?(isbegin_quest(ctx, 18115)) do
      changequest(ctx, 18115, 18116)
    else
      ctx
    end
  end

  defp send_ashore(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("What? How did you get on")
    |> mes("this ship?? You... No.")
    |> mes("I'll forgive you this once, but go")
    |> mes("back now.")
    |> close2()
    |> warp("moscovia", 163, 55)
  end

  defp choose_direction(ctx, args) do
    ctx =
      if Enum.random(1..Enum.at(args, 0, 0)) == 3 do
        ctx =
          ctx
          |> set_local(:ship2, :rand.uniform(4) - 1)
          |> set_local(:"d$", ["East", "West", "South", "North"])
          |> mes("[Mr. Ibanoff]")
          |> mes("Hm. The sea currents have changed.")
          |> mes("Adjust the rudder forward to the")

        ctx
        |> mes(
          Rathena.concat(
            Enum.at(get_local(ctx, :"d$", []), get_local(ctx, :ship2, 0), ""),
            ", to follow the currents."
          )
        )
        |> set_char_var(:mos_whale_edq, Enum.at(args, get_local(ctx, :ship2, 0) + 1, 0))
        |> close()
      else
        ctx
        |> mes("[Mr. Ibanoff]")
        |> mes("Nothing yet... Nothing has changed")
        |> mes("in the flow of water. There is")
        |> mes("nothing to note...")
        |> next()
        |> mes("[Mr. Ibanoff]")
        |> mes("We had better keep sailing on this heading for now.")
        |> close()
      end

    {ctx, nil}
  end

  defp remind_direction(ctx, args) do
    ctx =
      ctx
      |> set_local(:"d$", ["East", "West", "South", "North"])
      |> mes("[Mr. Ibanoff]")
      |> mes("Hey!")
      |> mes("Did you not hear me?")
      |> mes("Change the rudder forward to the")

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Enum.at(get_local(ctx, :"d$", []), Enum.at(args, 0, 0), ""),
          ", and follow the currents!"
        )
      )
      |> close()

    {ctx, nil}
  end
end
