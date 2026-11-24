defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Angelo do
  @moduledoc """
  Angelo asks adventurers to find his missing puppies.

  ## Behavior

  - Starts a daily search for three missing puppies and rewards their return.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "brasilis",
        x: 297,
        y: 307,
        dir: 5,
        sprite: 50,
        name: "Angelo",
        scope: :shared,
        unique_name: "Angelo#br"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnInit", ctx), do: initnpctimer(ctx)
  def on_event("OnTimer10000", ctx), do: ctx |> stopnpctimer() |> donpcevent("Angelo#br::OnGo")
  def on_event("OnGo", ctx), do: ctx |> emotion(:surprise) |> initnpctimer()

  @impl true
  def on_talk(ctx) do
    if base_level(ctx) < 40 do
      ctx
      |> mes("[Angelo]")
      |> mes("Pets went out the village~!!")
      |> mes("Gosh... what can I do... ?")
      |> close()
    else
      ctx = if checkquest(ctx, 9032, :playtime) == 2, do: erasequest(ctx, 9032), else: ctx
      quest_dialogue(ctx)
    end
  end

  defp quest_dialogue(ctx) do
    cond do
      checkquest(ctx, 9032, :playtime) == 0 ->
        ctx
        |> mes("[Angelo]")
        |> mes("The day is not finished yet.")
        |> mes("You can only help once a day. Hehe.")
        |> close()

      checkquest(ctx, 9030) == 1 ->
        ctx
        |> mes("[Angelo]")
        |> mes("My pets are in the field outside of the village.")
        |> mes("Why did they leave? Please find them.")
        |> close()

      checkquest(ctx, 9031) == 1 ->
        reward(ctx)

      true ->
        introduce(ctx)
    end
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("[Angelo]")
      |> mes("Oh, thank you. You found all of 3 puppies.")
      |> mes("Thanks a lot.")
      |> mes("I hope this is useful to you. hoho.")

    ctx =
      if Rathena.truthy?(get_char_var(ctx, :VIP_SCRIPT, 0)) and
           Rathena.truthy?(vip_status(ctx, 1)) do
        getexp(ctx, 75_000, 0)
      else
        getexp(ctx, 50_000, 0)
      end

    ctx = ctx |> erasequest(9031) |> setquest(9032) |> specialeffect2(:assumptio)
    ctx = if Rathena.truthy?(checkre(ctx, 0)), do: renewal_reward(ctx), else: ctx
    close(ctx)
  end

  defp renewal_reward(ctx) do
    ctx = ctx |> consumeitem(607) |> set_local(:rand, Enum.random(1..10))
    roll = get_local(ctx, :rand, 0)

    cond do
      roll > 4 and roll < 9 -> give_item(ctx, 504, 2)
      roll > 8 -> give_item(ctx, 608, 1)
      true -> ctx
    end
  end

  defp introduce(ctx) do
    ctx
    |> mes("[Angelo]")
    |> mes("Are you an adventurer? You came here right on time.")
    |> mes("Puppies have been disappearing.")
    |> mes("And someone said that they saw them out on the field just outside the village....")
    |> next()
    |> mes("[Angelo]")
    |> mes("It's pretty difficult and dangerous to find 'em.")
    |> mes("You have to find ^0000FF3 puppies^000000.")
    |> setquest(9030)
    |> close()
  end
end
