defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.Deviruchi do
  @moduledoc """
  Demon that tempts Acolytes to abandon the Priest spiritual training.

  ## Behavior

  - Taunts Priests who pass through, then lets them go.
  - Offers Acolytes an easier life and then a rare card; giving in to either temptation
    warps them out of the training.
  - Refusing both temptations lets the Acolyte continue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_prist",
        x: 168,
        y: 45,
        dir: 4,
        sprite: 1109,
        name: "Deviruchi",
        scope: :shared,
        unique_name: "Deviruchi#prst",
        trigger: {8, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @card_cutin "?Ì½?Æ®????Ä«??.bmp"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) -> taunt_priest(ctx)
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) -> tempt_acolyte(ctx)
      true -> ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp taunt_priest(ctx) do
    ctx
    |> mes("[Deviruchi]")
    |> mes("Whaaaaat...?")
    |> mes("What are you")
    |> mes("doing back here?")
    |> next()
    |> mes("[Deviruchi]")
    |> mes(
      "Well, look who's the ^660000BMOC^000000 now. That's '^660000B^000000ig ^660000M^000000an ^660000O^000000n ^660000C^000000ampus,' if you didn't know. By the way, I was being sarcastic. You know, if you didn't notice."
    )
    |> next()
    |> mes("[Deviruchi]")
    |> mes("Are you really")
    |> mes("happy being a Priest?")
    |> mes("There's no possible way.")
    |> next()
    |> mes("[Deviruchi]")
    |> mes(
      "Alright, alright, for old time's sake, I'll let you pass me. But only this once. But I better not catch you again! This is evil turf, you hear?!"
    )
    |> close()
  end

  defp tempt_acolyte(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Deviruchi]")
      |> mes("Why...")
      |> mes("Hello little Aco.")
      |> next()
      |> mes("[Deviruchi]")
      |> mes(
        "You must be here training hard to be a Priest. Funny, I know a lot of God's servants, actually. They tell me that it's really tough serving that God guy all the time. So... So ^666666tiring^000000 and ^666666unrewarding^000000."
      )
      |> next()
      |> mes("[Deviruchi]")
      |> mes(
        "I mean, people are always crying to Priests for help no matter where they are. And Priests never get anything in return..."
      )
      |> next()
      |> mes("[Deviruchi]")
      |> mes("It's tragic really, how unappreciated Priests are.")
      |> mes("It's so clear that any job is better. Anything at all...")
      |> next()
      |> mes("[Deviruchi]")
      |> mes(
        "Wouldn't life be so much easier if you weren't a Priest? And it'd be so easy. All you'd have to do is quit right now..."
      )
      |> next()
      |> select(["You're right, I quit!", "Out of my sight, demon!"])

    if choice == 1 do
      ctx
      |> mes("[Deviruchi]")
      |> mes("^660000YES~!^000000 I mean...")
      |> mes("Good for you!")
      |> next()
      |> mes("[Deviruchi]")
      |> mes("Oh...?")
      |> mes("Look at the ^660000time^000000.")
      |> mes("You better get going.")
      |> next()
      |> mes("[Deviruchi]")
      |> mes("BWAHAHAHAHAHAH!")
      |> mes("GET THE JOKE!?")
      |> close()
      |> warp("c_tower2", 168, 33)
    else
      offer_card(ctx)
    end
  end

  defp offer_card(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Deviruchi]")
      |> mes("Out of your sight?")
      |> mes("I guess I'm not the")
      |> mes("cutest thing you've")
      |> mes("ever seen, huh?")
      |> next()
      |> mes("[Deviruchi]")
      |> mes(
        "But how about this...? Now, isn't this an attractive sight? A nice, shiny new card. Mint condition. Not too many people have this you know. But I happen to have soooo many, my pockets hurt."
      )
      |> next()
      |> cutin(@card_cutin, 4)
      |> mes("[Deviruchi]")
      |> mes(
        "Isn't it everyone's dream to have one of these? Think about it, being a Priest can only bring you suffering..."
      )
      |> next()
      |> select(["You're right, I'll take it!", "Silence!"])

    if choice == 1 do
      ctx
      |> mes("[Deviruchi]")
      |> mes("Good choice!")
      |> mes("This card can")
      |> mes("can be yours...")
      |> next()
      |> cutin(@card_cutin, 255)
      |> mes("[Deviruchi]")
      |> mes("Theoretically!")
      |> mes("BWAHAHAHAHAHAHAHA!")
      |> mes("Go and earn it yourself!")
      |> close()
      |> warp("mjolnir_05", 200, 200)
    else
      ctx
      |> cutin(@card_cutin, 255)
      |> mes("[Deviruchi]")
      |> mes("Did...")
      |> mes("Did you just tell")
      |> mes("me to shut up?")
      |> mes("Oh my God...")
      |> next()
      |> mes("[Deviruchi]")
      |> mes("Sorry...")
      |> mes("Oh ^660000your^000000 God.")
      |> mes("Fine, get going.")
      |> mes("But you'll regret")
      |> mes("your decision later!")
      |> close()
    end
  end
end
