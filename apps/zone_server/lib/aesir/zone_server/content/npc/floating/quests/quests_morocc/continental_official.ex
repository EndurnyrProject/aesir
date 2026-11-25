defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsMorocc.ContinentalOfficial do
  @moduledoc """
  The Continental Guard official welcomes volunteers.

  ## Behavior

  - Eligible adventurers can register and are directed to Chief Balrog.

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
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Continental Official", scope: :shared},
      %{
        map: "morocc",
        x: 176,
        y: 103,
        dir: 3,
        sprite: 754,
        name: "Continental Official",
        scope: :pre_renewal,
        unique_name: "Continental Official#mor"
      },
      %{
        map: "morocc",
        x: 176,
        y: 101,
        dir: 3,
        sprite: 754,
        name: "Continental Official",
        scope: :renewal,
        unique_name: "Continental Official#mor"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :rebirth_moc_edq, 0)

    cond do
      progress > 3 ->
        ctx
        |> mes("[Continental Guard Official]")
        |> mes(
          "On behalf of the Continental Guard, I thank you for your efforts. Now, let me see if I've received any news from Headquarters that you should know..."
        )
        |> next()
        |> mes("[Continental Guard Official]")
        |> mes("Hmm...")
        |> next()
        |> mes("[Continental Guard Official]")
        |> mes("Nothing yet. Please carry on with your current mission. Once again, thank you.")
        |> close()

      progress == 0 ->
        {ctx, choice} =
          ctx
          |> mes("[Continental Guard Official]")
          |> mes("Welcome to the Morocc Subjugation Information Center. How may I help you?")
          |> next()
          |> select([
            "What is this place for?",
            "I'm here to volunteer.",
            "Tell me about the village situation."
          ])

        case choice do
          1 ->
            ctx
            |> mes("[Continental Guard Official]")
            |> mes(
              "I'm stationed here to assist adventurers who wish to volunteer and help the Continental Guard fight Satan Morocc."
            )
            |> next()
            |> mes("[Continental Guard Official]")
            |> mes(
              "I am sure you are already aware that Satan Morocc's revival threatens the peace of the Rune-Midgarts kingdom, and if Satan Morocc is allowed to roam free, it will devour the entire world."
            )
            |> next()
            |> mes("[Continental Guard Official]")
            |> mes(
              "The Continental Guard is currently planning an array of countermeasures to suppress Satan Morocc under the order of the kingdom."
            )
            |> next()
            |> mes("[Continental Guard Official]")
            |> mes(
              "If you have been invited by our messenger, or are confident in your skills, we encourage you to volunteer for the Continental Guards and bring peace back to this continent."
            )
            |> close()

          2 ->
            if base_level(ctx) > 79 do
              ctx = mes(ctx, "[Continental Guard Official]")

              ctx
              |> mes(
                Rathena.concat(
                  Rathena.concat("Welcome, ", char_name(ctx, 0)),
                  ". I've been waiting for you. I assume our messenger informed you of our situation."
                )
              )
              |> next()
              |> mes("[Continental Guard Official]")
              |> mes("Let me process your application immediately. Please wait.")
              |> next()
              |> mes("[Continental Guard Official]")
              |> mes(
                "Now please go speak to Chief Balrog of the Continental Guard. You can find him in the center."
              )
              |> set_char_var(:rebirth_moc_edq, 1)
              |> setquest(3050)
              |> close()
            else
              ctx
              |> mes("[Continental Guard Official]")
              |> mes(
                "I applaud you for your courage, but you will need more than just courage to help us."
              )
              |> next()
              |> mes("[Continental Guard Official]")
              |> mes(
                "Satan Morocc is most powerful evil that exists in the mortal world. Snuffing out your life would be so trivial to him."
              )
              |> next()
              |> mes("[Continental Guard Official]")
              |> mes(
                "I strongly recommend that you just think about your own safety for now. When the final battle comes, I am sure that no place will be safe."
              )
              |> close()
            end

          3 ->
            ctx
            |> mes("[Continental Guard Official]")
            |> mes(
              "As you can see, the situation can't be worse. The village and the surrounding area were irreparably damaged by Satan Morocc's resurrection."
            )
            |> next()
            |> mes("[Continental Guard Official]")
            |> mes(
              "Since the kingdom has dispatched Continental Guard Messengers everywhere, many able adventurers have flocked to this place, but... I'm afraid they still might not be enough to defeat the demon."
            )
            |> next()
            |> mes("[Continental Guard Official]")
            |> mes(
              "Please follow our instructions, at least around this area, and stay out of danger for now."
            )
            |> close()

          _ ->
            ctx
        end

      true ->
        ctx
        |> mes("[Continental Guard Official]")
        |> mes("Your application already has been registered. Please go speak to Chief Balrog.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
