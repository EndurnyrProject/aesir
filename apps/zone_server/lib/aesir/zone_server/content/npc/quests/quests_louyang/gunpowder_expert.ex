defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.GunpowderExpert do
  @moduledoc """
  Makes gunpowder for the Luoyang revolutionaries.

  ## Behavior

  - Checks the player's allegiance, party size and ingredients before offering gunpowder.
  - Exchanges the chemicals for gunpowder and cautions the player about inspection.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in01",
        x: 43,
        y: 147,
        dir: 3,
        sprite: 750,
        name: "Gunpowder Expert",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_make, 0) == 0 do
      prepare_gunpowder(ctx)
    else
      if Rathena.truthy?(count_item(ctx, 7204)),
        do: warn_about_inspection(ctx),
        else: farewell(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp prepare_gunpowder(ctx) do
    {ctx, _} = getpartymember(ctx, getcharid(ctx, 1))
    ctx = set_temp_var(ctx, :partymember, get_server_temp_var(ctx, "partymembercount", 0))

    cond do
      not Rathena.truthy?(get_char_var(ctx, :QL_REVOL, 0)) ->
        distrust(ctx)

      get_temp_var(ctx, :partymember, 0) != 8 ->
        wrong_party_size(ctx)

      Rathena.truthy?(count_item(ctx, 7068)) and Rathena.truthy?(count_item(ctx, 7096)) and
          Rathena.truthy?(count_item(ctx, 7004)) ->
        offer_gunpowder(ctx)

      true ->
        missing_chemicals(ctx)
    end
  end

  defp distrust(ctx) do
    ctx
    |> mes("[Hao Chenryu]")
    |> mes("Who...")
    |> mes("Are you?")
    |> next()
    |> mes("[Hao Chenryu]")
    |> mes(
      "I only trust my comrades in the cause for Luoyang, so leave me alone. Death before oppression! Freedom for Luoyang!"
    )
    |> close()
  end

  defp wrong_party_size(ctx) do
    ctx
    |> mes("[Hao Chenryu]")
    |> mes("Mao told me that eight Midgardians")
    |> mes("would be coming.")
    |> mes("But what happened?")
    |> mes("I'm confused...")
    |> next()
    |> mes("[Hao Chenryu]")
    |> mes("Mao's plans are flawless,")
    |> mes(
      "so I'm sticking to the scenario he's drawn up. You're either improvising needlessly, or you're not really my comrade..."
    )
    |> close()
  end

  defp make_gunpowder(ctx) do
    ctx
    |> delitem(7068, 1)
    |> delitem(7096, 1)
    |> delitem(7004, 1)
    |> mes("[Hao Chenryu]")
    |> mes(
      "I don't want you to be caught if the soldiers inspect your goods. It will be better if one of you carry a Cart and hide the gunpowder in there."
    )
    |> set_char_var(:ch_make, 1)
    |> give_item(7204, 1)
    |> close()
  end

  defp cancel(ctx) do
    ctx
    |> mes("[Hao Chenryu]")
    |> mes("Is...")
    |> mes("Something wrong?!")
    |> next()
    |> mes("[Hao Chenryu]")
    |> mes("I guess we must")
    |> mes("be extra careful,")
    |> mes("as there is much")
    |> mes("surveillance in")
    |> mes("this place.")
    |> close()
  end

  defp missing_chemicals(ctx) do
    ctx
    |> mes("[Hao Chenryu]")
    |> mes("Hmmm...")
    |> mes("It seems like")
    |> mes("you're one of us.")
    |> next()
    |> mes("[Hao Chenryu]")
    |> mes("If you came for the")
    |> mes("gunpowder, you should")
    |> mes("get some chemcials")
    |> mes("from your party leader.")
    |> close()
  end

  defp warn_about_inspection(ctx) do
    ctx
    |> mes("[Hao Chenryu]")
    |> mes("Be careful!")
    |> mes("It's easy for")
    |> mes("gunpowder to be")
    |> mes("found during the")
    |> mes("inspection process!")
    |> mes("Hide it well...!")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Hao Chenryu]")
    |> mes(
      "I hope you bring the gunpowder to Mao safely. The next time you see him, please give him my thanks."
    )
    |> close()
  end

  defp offer_gunpowder(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hao Chenryu]")
      |> mes("Ah, I see that Mao")
      |> mes("has sent you. I'm sorry")
      |> mes("for the trouble you've")
      |> mes("gone through to smuggle")
      |> mes("the chemicals to me, comrade.")
      |> next()
      |> mes("[Hao Chenryu]")
      |> mes("Please give me")
      |> mes("a minute so that")
      |> mes("I may quickly make")
      |> mes("the gunpowder.")
      |> next()
      |> select(["Make Gunpowder.", "Cancel."])

    case choice do
      1 -> make_gunpowder(ctx)
      2 -> cancel(ctx)
      _ -> ctx
    end
  end
end
