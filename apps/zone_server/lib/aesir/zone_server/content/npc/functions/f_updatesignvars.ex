defmodule Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars do
  @moduledoc """
  Migrates legacy Sign quest progress to the current variables.

  ## Behavior

  - Restores quest progress from legacy variables and clears them after migration.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  import Aesir.ZoneServer.Script.Dsl, warn: false
  alias Aesir.ZoneServer.Script.Rathena

  @doc "Callable rAthena global function; returns `{ctx, return_value}`."
  def call(ctx, args) do
    scoped_call(ctx, args, &run/2)
  end

  defp run(ctx, _args) do
    ctx =
      if not Rathena.truthy?(get_char_var(ctx, :sign_q, 0)) do
        legacy_progress = get_char_var(ctx, :signquest, 0)

        ctx =
          cond do
            legacy_progress <= 4 ->
              set_char_var(ctx, :sign_q, legacy_progress)

            legacy_progress == 5 ->
              set_char_var(ctx, :sign_q, 14)

            legacy_progress == 6 ->
              set_char_var(ctx, :sign_q, 15)

            legacy_progress == 7 ->
              set_char_var(ctx, :sign_q, 17)

            legacy_progress == 8 ->
              set_char_var(ctx, :sign_q, 19)

            legacy_progress == 9 ->
              set_char_var(ctx, :sign_q, 20)

            legacy_progress == 10 ->
              set_char_var(ctx, :sign_q, 25)

            legacy_progress == 11 ->
              set_char_var(ctx, :sign_q, 27)

            legacy_progress == 12 ->
              set_char_var(ctx, :sign_q, 35)

            legacy_progress == 13 ->
              set_char_var(ctx, :sign_q, 53)

            legacy_progress >= 14 and legacy_progress <= 15 ->
              set_char_var(ctx, :sign_q, 54)

            legacy_progress >= 16 and legacy_progress <= 18 ->
              set_char_var(
                ctx,
                :sign_q,
                legacy_progress + 39
              )

            legacy_progress == 19 and Rathena.truthy?(count_item(ctx, 7278)) ->
              set_char_var(ctx, :sign_q, 61)

            legacy_progress == 20 ->
              set_char_var(ctx, :sign_q, 65)

            legacy_progress == 21 ->
              set_char_var(ctx, :sign_q, 69)

            legacy_progress >= 22 and legacy_progress <= 28 ->
              set_char_var(
                ctx,
                :sign_q,
                legacy_progress + 48
              )

            legacy_progress >= 29 and legacy_progress <= 34 ->
              set_char_var(
                ctx,
                :sign_q,
                legacy_progress + 49
              )

            legacy_progress == 35 ->
              ctx |> set_char_var(:sign_q, 83) |> set_char_var(:sign_sq, 1)

            legacy_progress == 36 ->
              ctx |> set_char_var(:sign_q, 83) |> set_char_var(:sign_sq, 1)

            legacy_progress == 37 ->
              ctx |> set_char_var(:sign_q, 83) |> set_char_var(:sign_sq, 2)

            legacy_progress == 38 ->
              ctx |> set_char_var(:sign_q, 83) |> set_char_var(:sign_sq, 3)

            legacy_progress == 39 ->
              ctx |> set_char_var(:sign_q, 83) |> set_char_var(:sign_sq, 5)

            legacy_progress == 40 ->
              ctx |> set_char_var(:sign_q, 83) |> set_char_var(:sign_sq, 6)

            legacy_progress == 41 ->
              ctx |> set_char_var(:sign_q, 83) |> set_char_var(:sign_sq, 7)

            legacy_progress == 42 ->
              ctx |> set_char_var(:sign_q, 83) |> set_char_var(:sign_sq, 8)

            legacy_progress >= 43 and legacy_progress <= 48 ->
              set_char_var(
                ctx,
                :sign_q,
                legacy_progress + 42
              )

            legacy_progress >= 49 and legacy_progress <= 52 ->
              set_char_var(
                ctx,
                :sign_q,
                legacy_progress + 44
              )

            legacy_progress == 53 ->
              set_char_var(ctx, :sign_q, 100)

            legacy_progress == 54 ->
              set_char_var(ctx, :sign_q, 117)

            legacy_progress == 55 ->
              set_char_var(ctx, :sign_q, 118)

            legacy_progress == 56 ->
              set_char_var(ctx, :sign_q, 127)

            legacy_progress == 57 ->
              set_char_var(ctx, :sign_q, 129)

            legacy_progress == 58 ->
              set_char_var(ctx, :sign_q, 130)

            legacy_progress >= 59 and legacy_progress <= 66 ->
              set_char_var(
                ctx,
                :sign_q,
                legacy_progress + 78
              )

            true ->
              ctx
          end

        ctx =
          cond do
            get_char_var(ctx, :sign_fail, 0) == 1 -> set_char_var(ctx, :sign_q, 200)
            get_char_var(ctx, :sign_fail, 0) >= 2 -> set_char_var(ctx, :sign_q, 201)
            true -> ctx
          end

        ctx =
          if get_char_var(ctx, :ariantest, 0) >= 2 do
            set_char_var(ctx, :sign_q, get_char_var(ctx, :ariantest, 0) + 3)
          else
            ctx
          end

        ctx =
          if get_char_var(ctx, :gaanantest, 0) == 1 do
            set_char_var(ctx, :sign_q, 12)
          else
            ctx
          end

        ctx =
          if get_char_var(ctx, :SignJore, 0) == 1 do
            set_char_var(ctx, :sign_q, 16)
          else
            ctx
          end

        ctx =
          if get_char_var(ctx, :ScareAlchSign, 0) == 1 do
            set_char_var(ctx, :sign_q, 18)
          else
            ctx
          end

        ctx =
          cond do
            get_char_var(ctx, :dearles_test, 0) == 1 -> set_char_var(ctx, :sign_q, 28)
            get_char_var(ctx, :dearles_test, 0) == 2 -> set_char_var(ctx, :sign_q, 29)
            get_char_var(ctx, :dearles_test, 0) == 3 -> set_char_var(ctx, :sign_q, 30)
            true -> ctx
          end

        ctx =
          cond do
            get_char_var(ctx, :SignDance, 0) == 1 -> set_char_var(ctx, :sign_q, 32)
            get_char_var(ctx, :SignDance, 0) == 2 -> set_char_var(ctx, :sign_q, 33)
            true -> ctx
          end

        ctx =
          cond do
            get_char_var(ctx, :bakerlan_test, 0) >= 1 and
                get_char_var(ctx, :bakerlan_test, 0) <= 3 ->
              set_char_var(ctx, :sign_q, get_char_var(ctx, :bakerlan_test, 0) + 35)

            get_char_var(ctx, :bakerlan_test, 0) >= 4 and
                get_char_var(ctx, :bakerlan_test, 0) <= 6 ->
              set_char_var(ctx, :sign_q, get_char_var(ctx, :bakerlan_test, 0) + 36)

            get_char_var(ctx, :bakerlan_test, 0) >= 7 and
                get_char_var(ctx, :bakerlan_test, 0) <= 13 ->
              set_char_var(ctx, :sign_q, get_char_var(ctx, :bakerlan_test, 0) + 39)

            true ->
              ctx
          end

        ctx =
          if get_char_var(ctx, :signanvil, 0) >= 1 and get_char_var(ctx, :signanvil, 0) <= 4 do
            set_char_var(ctx, :sign_sq, get_char_var(ctx, :signanvil, 0) + 57)
          else
            ctx
          end

        ctx =
          if get_char_var(ctx, :signlaichin, 0) >= 1 do
            ctx = mes(ctx, "^FF0000You stumble and drop the your^000000")

            ctx =
              if Rathena.truthy?(count_item(ctx, 7306)) do
                mes(
                  ctx,
                  Rathena.concat(Rathena.concat("^FF0000", Rathena.getitemname(7306)), "^000000")
                )
              else
                ctx
              end

            ctx =
              if Rathena.truthy?(count_item(ctx, 7306)) and Rathena.truthy?(count_item(ctx, 7307)) do
                mes(ctx, "^FF0000and^000000")
              else
                ctx
              end

            ctx =
              if Rathena.truthy?(count_item(ctx, 7307)) do
                mes(
                  ctx,
                  Rathena.concat(Rathena.concat("^FF0000", Rathena.getitemname(7307)), "^000000")
                )
              else
                ctx
              end

            ctx =
              mes(
                ctx,
                "^FF0000pieces on the ground and they vanish! Perhaps you should talk to Lachin.^000000"
              )

            ctx = delitem(ctx, 7306, count_item(ctx, 7306))

            ctx
            |> delitem(7307, count_item(ctx, 7307))
            |> set_char_var(:sign_q, Enum.random(97..100))
          else
            ctx
          end

        ctx =
          if Rathena.truthy?(get_char_var(ctx, :signengelhour, 0)) do
            ctx
            |> mes(
              "^FF0000You see that Engel has forgotten to look at 'The Sign', how you got it back is a mystery too you, but you should remind Engel that he needs to look at it.^000000"
            )
            |> give_item(7314, 1)
            |> set_char_var(:sign_q, 139)
          else
            ctx
          end

        ctx =
          cond do
            get_char_var(ctx, :Sign_Branch8A, 0) == 1 ->
              set_char_var(ctx, :sign_q, 119)

            get_char_var(ctx, :Sign_Branch8A, 0) == 2 ->
              set_char_var(ctx, :sign_q, 120)

            get_char_var(ctx, :Sign_Branch8A, 0) == 3 ->
              set_char_var(ctx, :sign_q, 122)

            get_char_var(ctx, :Sign_Branch8A, 0) == 4 ->
              set_char_var(ctx, :sign_q, 124)

            get_char_var(ctx, :Sign_Branch8A, 0) == 5 ->
              set_char_var(ctx, :sign_q, 134)

            get_char_var(ctx, :Sign_Branch8A, 0) == 7 or get_char_var(ctx, :Sign_Branch8A, 0) == 8 ->
              set_char_var(ctx, :sign_q, 126)

            true ->
              ctx
          end

        ctx =
          if get_char_var(ctx, :Sign_Branch8B, 0) > 0 do
            ctx
            |> mes("^FF0000Something is wrong, perhaps you should go talk to Serin again.^000000")
            |> set_char_var(:sign_q, 132)
          else
            ctx
          end

        ctx =
          if Rathena.truthy?(get_char_var(ctx, :Sign_Branch2B, 0)) do
            set_char_var(ctx, :sign_q, 91)
          else
            ctx
          end

        ctx =
          if Rathena.truthy?(get_char_var(ctx, :signmetzhour, 0)) do
            ctx
            |> mes(
              "^FF0000You see that Metz has forgotten to look at 'The Sign', how you got it back is a mystery too you, but you should remind Metz that he needs to look at it.^000000"
            )
            |> give_item(7314, 1)
            |> set_char_var(:sign_q, 138)
          else
            ctx
          end

        ctx
        |> set_char_var(:signquest, 0)
        |> set_char_var(:sign_fail, 0)
        |> set_char_var(:gaananpoint, 0)
        |> set_char_var(:gaanantest, 0)
        |> set_char_var(:ariantest, 0)
        |> set_char_var(:SignJore, 0)
        |> set_char_var(:ScareAlchSign, 0)
        |> set_char_var(:dearles_test, 0)
        |> set_char_var(:SignDance, 0)
        |> set_char_var(:bakerlan_test, 0)
        |> set_char_var(:signanvil, 0)
        |> set_char_var(:signengelhour, 0)
        |> set_char_var(:signlaichin, 0)
        |> set_char_var(:Sign_Seal1, 0)
        |> set_char_var(:Sign_Seal2, 0)
        |> set_char_var(:Sign_Seal3, 0)
        |> set_char_var(:Sign_Seal4, 0)
        |> set_char_var(:"Sign_Seal1$", "")
        |> set_char_var(:"Sign_Seal2$", "")
        |> set_char_var(:"Sign_Seal3$", "")
        |> set_char_var(:"Sign_Seal4$", "")
        |> set_char_var(:brokenseal, 0)
        |> set_char_var(:Sign_Branch8A, 0)
        |> set_char_var(:Sign_Branch8B, 0)
        |> set_char_var(:Sign_Branch2B, 0)
        |> set_char_var(:serinring, 0)
        |> set_char_var(:signmetzhour, 0)
      else
        ctx
      end

    {ctx, nil}
  end
end
