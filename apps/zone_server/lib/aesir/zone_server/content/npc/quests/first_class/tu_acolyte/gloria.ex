defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.Gloria do
  @moduledoc """
  Gloria, a young Acolyte trainee at the convent who can open a Warp Portal to Prontera.

  ## Behavior

  - During the Acolyte training quest, offers Acolytes a free warp to Prontera.
  - Acolytes who have not started or have finished the training get admiration instead.
  - Other classes hear the story behind her name.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 219,
        y: 164,
        dir: 3,
        sprite: 95,
        name: "Gloria",
        scope: :shared,
        unique_name: "Gloria#tu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Gloria]")

    cond do
      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:acolyte) ->
        tell_name_story(ctx)

      get_char_var(ctx, :tu_acolyte01, 0) > 0 and get_char_var(ctx, :tu_acolyte01, 0) < 25 ->
        offer_warp(ctx)

      true ->
        admire_skills(ctx)
    end
  end

  defp tell_name_story(ctx) do
    ctx
    |> mes("Hi, hi~")
    |> mes("I'm Gloria.")
    |> mes("You wanna know")
    |> mes("something neat")
    |> mes("about my name?")
    |> next()
    |> mes("[Gloria]")
    |> mes(
      "My father was a Blacksmith in Geffen, and supposedly he finished an incredible weapon on the day"
    )
    |> mes("I was born. He thought it was a sign of good luck, so he named")
    |> mes("the weapon after me!")
    |> next()
    |> mes("[Gloria]")
    |> mes("It's a little strange knowing that there's a weapon named after")
    |> mes(
      "you, but I like my name very much. I mean, it's not like my parents named me after that weapon, right?"
    )
    |> close()
  end

  defp offer_warp(ctx) do
    {ctx, choice} =
      ctx
      |> mes("I'm still")
      |> mes("a young Acolyte")
      |> mes("in training and I'm")
      |> mes("always making mistakes!")
      |> next()
      |> mes("[Gloria]")
      |> mes("^333333*Sniff*^000000")
      |> mes("And I get scolded")
      |> mes("almost all the time...")
      |> mes("But there's one thing")
      |> mes("that I can do really well!")
      |> next()
      |> mes("[Gloria]")
      |> mes("Warp portal!")
      |> mes("I know Level 2 Warp Portal!")
      |> mes("One of my Memo Points is here")
      |> mes("and the other is in Prontera.")
      |> next()
      |> mes("[Gloria]")
      |> mes("Anyway, whenever")
      |> mes("you need to, I can")
      |> mes("send you to Prontera.")
      |> mes("Just let me know, okay?")
      |> next()
      |> select(["I'm okay for now.", "Send me to Prontera."])

    case choice do
      1 ->
        ctx
        |> mes("[Gloria]")
        |> mes("In order to use")
        |> mes("Warp Portal, you need")
        |> mes("one ^3131FFBlue Gemstone^000000.")
        |> mes("Is this to help me?")
        |> mes("Wow, I'm touched!")
        |> emotion(:cry)
        |> close()

      2 ->
        ctx
        |> mes("[Gloria]")
        |> mes("Leave it to me!")
        |> mes("Here we go~!!")
        |> mes("W-warp Portal!")
        |> close()
        |> warp("prontera", 116, 72)

      _ ->
        admire_skills(ctx)
    end
  end

  defp admire_skills(ctx) do
    ctx
    |> mes("Wow...")
    |> mes("Did you learn all that from Asthe? That's so great...")
    |> mes("You must be so much better than me that I can't even brag about warping to")
    |> mes("Prontera anymore. ^333333*Sniff*^000000")
    |> close()
  end
end
