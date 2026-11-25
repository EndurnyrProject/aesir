defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Rudder do
  @moduledoc """
  Steers the quest ship under Mr. Ibanoff’s direction.

  ## Behavior

  - Accepts steering choices and may summon monsters during the voyage.

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
        x: 101,
        y: 111,
        dir: 4,
        sprite: 111,
        name: "rudder",
        scope: :shared,
        unique_name: "rudder#ship"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :mos_whale_edq, 0)

    cond do
      stage == 5 ->
        steer_and_finish(ctx, 1, 0)

      stage == 4 ->
        ctx
        |> mes("[Mr. Ibanoff]")
        |> mes("You don't have to adjust the rudder for now.")
        |> mes("Wait for my direction.")
        |> close()

      stage == 6 ->
        wait_for_orders(ctx)

      get_server_temp_var(ctx, "mos1_edq", 0) > 0 ->
        ctx
        |> mes("[Mr. Ibanoff]")
        |> mes("We should make sure to kill any")
        |> mes("monsters onboard.")
        |> close()

      stage == 7 ->
        steer_and_finish(ctx, 4, 1)

      stage in [8, 21, 23] ->
        wait_for_orders(ctx)

      stage in 91..94 ->
        steer_and_finish(ctx, stage - 90, 2)

      stage in 11..12 ->
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
        |> close()

      stage == 20 ->
        steer_and_finish(ctx, 1, 0)

      stage == 22 ->
        steer_and_finish(ctx, 4, 1)

      stage in 241..243 ->
        steer_and_finish(ctx, stage - 240, 2)

      stage == 244 ->
        steer_and_finish(ctx, 4, 1)

      stage == 25 ->
        ctx
        |> mes("[Mr. Ibanoff]")
        |> mes("You can adjust the rudder,")
        |> mes("under my direction.")
        |> close()

      stage == 26 ->
        ctx
        |> mes("[Mr. Ibanoff]")
        |> mes("Hey! Listen to what I am saying.")
        |> mes("How come you go there without my")
        |> mes("permission...")
        |> close()

      true ->
        send_ashore(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp wait_for_orders(ctx) do
    ctx
    |> mes("[Mr. Ibanoff]")
    |> mes("Do not yet adjust the rudder.")
    |> mes("Only when I order you to,")
    |> mes("you adjust the rudder.")
    |> close()
  end

  defp steer_and_finish(ctx, direction, monster_setting) do
    ctx = ctx |> mes("Which way?") |> next()
    {ctx, choice} = select(ctx, ["0", "East", "West", "South", "North"])
    direction_name = Enum.at(["0", "East", "West", "South", "North"], direction)

    if choice - 1 == direction do
      correct_direction(ctx, direction_name, monster_setting)
    else
      wrong_direction(ctx, direction_name, monster_setting)
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
    |> warp("moscovia", 162, 56)
  end

  defp correct_direction(ctx, direction, monster_setting) do
    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("Good. Firstly, we should")
      |> mes("keep heading #{String.downcase(direction)} this way.")
      |> mes("When I give the order,")
      |> mes("please adjust the rudder again.")

    roll = if monster_setting == 2, do: Enum.random(1..4), else: 0

    ctx =
      if monster_setting == 2 and roll == 3 do
        ctx =
          ctx
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("Wait! Something has appeared in front of us...")
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("Monsters!!!")
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("These monsters are like none I have")
          |> mes("ever encountered! Be careful! We")
          |> mes("must repulse these monsters!")

        ctx = set_server_temp_var(ctx, "mos1_edq", get_server_temp_var(ctx, "mos1_edq", 0) + 1)

        event =
          if get_char_var(ctx, :mos_whale_edq, 0) >= 241,
            do: "Baehideun4#ship::OnEnable",
            else: "Baehideun3#ship::OnEnable"

        donpcevent(ctx, event)
      else
        ctx
      end

    stage = get_char_var(ctx, :mos_whale_edq, 0)

    next_stage =
      cond do
        monster_setting != 2 -> stage + 1
        stage >= 241 and roll != 3 -> 26
        stage >= 241 -> 25
        roll != 3 -> 10
        true -> 11
      end

    ctx |> set_char_var(:mos_whale_edq, next_stage) |> close()
  end

  defp wrong_direction(ctx, direction, monster_setting) do
    ctx =
      ctx
      |> mes("[Mr. Ibanoff]")
      |> mes("I said that we should go #{direction}!")
      |> mes("You should sail in the right")
      |> mes("direction! To the #{String.downcase(direction)}!")

    ctx =
      if monster_setting >= 1 and Enum.random(1..if(monster_setting == 1, do: 5, else: 4)) <= 2 do
        ctx =
          ctx
          |> next()
          |> mes("[Mr. Ibanoff]")
          |> mes("Oh no! Monsters have appeared!")
          |> mes("Let's get ready to fight! Hurry!")

        ctx
        |> set_server_temp_var("mos1_edq", get_server_temp_var(ctx, "mos1_edq", 0) + 1)
        |> donpcevent("Baehideun1#ship::OnEnable")
      else
        ctx
      end

    close(ctx)
  end
end
