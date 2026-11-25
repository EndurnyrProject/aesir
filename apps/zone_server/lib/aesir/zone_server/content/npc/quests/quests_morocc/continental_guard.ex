defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.ContinentalGuard do
  @moduledoc """
  A Continental Guard restricts access to the dangerous Morocc fields.

  ## Behavior

  - Dialogue and field access depend on quest progress, party membership, and a certificate.
  - The guard can send players to the accident site in Morocc.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - The first gate was `(rebirth_moc_edq == 0) && (rebirth_moc_edq < 4)`, which left quest
    stages 1-3 without dialogue; it is `rebirth_moc_edq < 4` here, matching the next
    branch's `rebirth_moc_edq > 3`.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild20",
        x: 354,
        y: 183,
        dir: 3,
        sprite: 707,
        name: "Continental Guard",
        scope: :shared,
        unique_name: "MocConGuard",
        hidden_name: "01",
        trigger: {3, 3}
      },
      %{
        map: "moc_fild20",
        x: 354,
        y: 174,
        dir: 3,
        sprite: 707,
        name: "Continental Guard",
        scope: :shared,
        unique_name: "Continental Guard#02",
        trigger: {3, 3}
      },
      %{
        map: "moc_fild20",
        x: 38,
        y: 174,
        dir: 5,
        sprite: 707,
        name: "Continental Guard",
        scope: :shared,
        unique_name: "Continental Guard#03",
        trigger: {3, 3}
      },
      %{
        map: "moc_fild20",
        x: 38,
        y: 183,
        dir: 5,
        sprite: 707,
        name: "Continental Guard",
        scope: :shared,
        unique_name: "Continental Guard#04",
        trigger: {3, 3}
      },
      %{
        map: "moc_fild20",
        x: 189,
        y: 21,
        dir: 7,
        sprite: 707,
        name: "Continental Guard",
        scope: :shared,
        unique_name: "Continental Guard#05",
        trigger: {3, 3}
      },
      %{
        map: "moc_fild20",
        x: 200,
        y: 21,
        dir: 7,
        sprite: 707,
        name: "Continental Guard",
        scope: :shared,
        unique_name: "Continental Guard#06",
        trigger: {3, 3}
      },
      %{
        map: "moc_fild20",
        x: 203,
        y: 336,
        dir: 5,
        sprite: 707,
        name: "Continental Guard",
        scope: :shared,
        unique_name: "Continental Guard#07",
        trigger: {3, 3}
      },
      %{
        map: "moc_fild20",
        x: 215,
        y: 336,
        dir: 3,
        sprite: 707,
        name: "Continental Guard",
        scope: :shared,
        unique_name: "Continental Guard#08",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @cpc_account 2

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :rebirth_moc_edq, 0)

    cond do
      progress < 4 -> explain_restriction(ctx)
      progress > 3 and progress < 8 -> investigation_menu(ctx)
      progress == 8 -> veteran_menu(ctx)
      true -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp explain_restriction(ctx) do
    {ctx, choice} =
      ctx
      |> restriction()
      |> next()
      |> select(["Cancel Conversation", "Ask What Happened"])

    case choice do
      1 -> close(ctx)
      2 -> explain_incident(ctx)
      _ -> ctx
    end
  end

  defp explain_incident(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Continental Guard]")
      |> mes(
        "Didn't you know? Satan Morocc has resurrected and broke out of Morocc Village where he was confined."
      )
      |> next()
      |> mes("[Continental Guard]")
      |> mes(
        "His resurrection has caused irreparable damage to the village and to the desert around it, and now he has moved to the Sograt Desert."
      )
      |> next()
      |> mes("[Continental Guard]")
      |> mes(
        "We are here to carry out the orders of the Prontera Kingdom by preventing commoners, aside from the members of the Morocc Subjugation, from accessing the area."
      )
      |> next()
      |> mes("[Continental Guard]")
      |> mes(
        "If you'd like to know more information, I suggest that you speak to the Continental Guard in charge of the accident site in Morocc Village."
      )
      |> next()
      |> select(["End Conversation", "Ask About Guard's Location"])

    case choice do
      1 -> close(ctx)
      2 -> offer_accident_site(ctx)
      _ -> ctx
    end
  end

  defp offer_accident_site(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Continental Guard]")
      |> mes(
        "The guard that you want to talk to is at a camp built in the center of Morocc Village."
      )
      |> next()
      |> mes("[Continental Guard]")
      |> mes("If you'd like, I can send you there directly.")
      |> next()
      |> select(["No, thanks.", "Please do."])

    case choice do
      1 ->
        ctx
        |> mes("[Continental Guard]")
        |> mes(
          "I see. Well then, for your safety, please leave this dangerous area as soon as possible."
        )
        |> close()

      2 ->
        send_to_accident_site(ctx)

      _ ->
        ctx
    end
  end

  defp investigation_menu(ctx) do
    {ctx, choice} =
      ctx
      |> restriction()
      |> next()
      |> select([
        "Cancel Conversation",
        "Enter the Field to Investigate",
        "Move to Morocc's Accident Site"
      ])

    case choice do
      1 -> close(ctx)
      2 -> investigate_first_field(ctx)
      3 -> send_to_accident_site(ctx)
      _ -> ctx
    end
  end

  defp investigate_first_field(ctx) do
    if get_server_temp_var(ctx, "re_moc", 0) < 3 do
      ctx |> prepare_party() |> enter_field("moc_fild21")
    else
      ctx
      |> mes("[Continental Guard]")
      |> mes(
        "We've received orders from Headquarters to block access to this area since an unusual space-time phenomenon has been detected from the Morocc field."
      )
      |> next()
      |> mes("[Continental Guard]")
      |> mes(
        "We need to wait until the phenomenon is over, and then we'll let you proceed with your investigation."
      )
      |> close()
    end
  end

  defp veteran_menu(ctx) do
    ctx =
      ctx
      |> mes("[Continental Guard]")
      |> mes(
        "Ah, you're an adventurer working for the Continental Guard. Nice to meet you. Feel free to ask me if you need my assistance."
      )
      |> next()
      |> prepare_party()

    {ctx, choice} =
      select(ctx, [
        "Enter the First Field to Investigate",
        "Enter the Second Field to Investigate",
        "Return to Morocc's Accident Site",
        "Cancel Conversation"
      ])

    case choice do
      1 -> enter_field(ctx, "moc_fild21")
      2 -> enter_field(ctx, "moc_fild22")
      3 -> send_to_accident_site(ctx)
      4 -> close(ctx)
      _ -> ctx
    end
  end

  defp prepare_party(ctx) do
    {ctx, count} = getpartymember(ctx, getcharid(ctx, 1), :char_id, ".@partymembercid")

    online =
      ctx
      |> get_local(:partymembercid, [])
      |> Enum.take(count)
      |> Enum.count(&Rathena.truthy?(convertpcinfo(ctx, &1, @cpc_account)))

    set_local(ctx, :onlinemembers, get_local(ctx, :onlinemembers, 0) + online)
  end

  defp enter_field(ctx, map) do
    cond do
      get_local(ctx, :onlinemembers, 0) > 1 and count_item(ctx, 7826) > 0 ->
        ctx
        |> mes("[Continental Guard]")
        |> mes("......")
        |> next()
        |> mes("[Continental Guard]")
        |> mes(
          "Yes, I've confirmed that you're a member of the Continental Guards. I wish you good luck in accomplishing your mission."
        )
        |> next()
        |> mes("[Continental Guard]")
        |> mes(
          "I'll send you to the field shortly. Please use the warp at the field entrance to come back to this area."
        )
        |> close2()
        |> warp(map, 38, 193)

      get_local(ctx, :onlinemembers, 0) < 2 and count_item(ctx, 7826) > 0 ->
        message =
          if map == "moc_fild22",
            do:
              "...So please go back to the site, and come back in a party of at least 2 members. Thank you.",
            else:
              "...You understand that, right? Please go back to the site, and come back in a party of at least 2 members. Thank you."

        ctx
        |> mes("[Continental Guard]")
        |> mes(
          "Welcome, members of the Continental Guards. I have a special order from Chief Balrog for you, so let me read it for you."
        )
        |> next()
        |> mes("[Continental Guard]")
        |> mes(
          "'Due to the dangers of this area, I hereby prohibit members of the Continental Guard to investigate the area alone. You must organize a party of at least 2 members to carry out your missions from now on.'"
        )
        |> next()
        |> mes("[Continental Guard]")
        |> mes(message)
        |> close()

      count_item(ctx, 7826) < 1 ->
        ctx
        |> mes("[Continental Guard]")
        |> mes(
          "Only members of the Continental Guards with Continental Guard Certificates are allowed to proceed beyond this point."
        )
        |> close()

      true ->
        close(ctx)
    end
  end

  defp send_to_accident_site(ctx) do
    ctx
    |> mes("[Continental Guard]")
    |> mes("Great. I'll send you to Morocc Village's accident site shortly.")
    |> close2()
    |> warp("morocc", 160, 61)
  end

  def ev_ontouch(ctx), do: ctx |> restriction() |> close()

  defp restriction(ctx) do
    ctx
    |> mes("[Continental Guard]")
    |> mes("No commoners are allowed in the area beyond this point.")
    |> mes("This place is extremely dangerous so you are restricted from entering.")
  end
end
