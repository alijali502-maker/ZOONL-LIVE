CREATE OR REPLACE FUNCTION public.send_live_gift(p_gift_id uuid, p_room_id uuid, p_quantity integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
      declare
        v_sender uuid;
          v_host uuid;
            v_room_live boolean;
              v_room_private boolean;
                v_room_locked boolean;
                  v_gift_name text;
                    v_coin_price bigint;
                      v_diamond_value bigint;
                        v_total_coins bigint;
                          v_total_diamonds bigint;
                            v_sender_coins bigint;
                            begin
                              v_sender := auth.uid();

                                if v_sender is null then
                                    raise exception 'LOGIN_REQUIRED';
                                      end if;

                                        if p_quantity is null or p_quantity < 1 then
                                            raise exception 'INVALID_QUANTITY';
                                              end if;

                                                select owner_id, is_live, is_private, is_locked
                                                  into v_host, v_room_live, v_room_private, v_room_locked
                                                    from public.live_rooms
                                                      where id = p_room_id;

                                                        if not found then
                                                            raise exception 'ROOM_NOT_FOUND';
                                                              end if;

                                                                if v_room_live is distinct from true then
                                                                    raise exception 'ROOM_NOT_LIVE';
                                                                      end if;

                                                                        if v_host = v_sender then
                                                                            raise exception 'CANNOT_SEND_GIFT_TO_SELF';
                                                                              end if;

                                                                                if (v_room_private or v_room_locked) and not exists (
                                                                                    select 1
                                                                                        from public.live_room_members
                                                                                            where room_id = p_room_id
                                                                                                  and user_id = v_sender
                                                                                                    ) and not exists (
                                                                                                      select 1
                                                                                                      from public.room_guest_seats
                                                                                                      where room_id = p_room_id
                                                                                                        and user_id = v_sender
                                                                                                        and seat_status = 'occupied'
                                                                                                    ) then
                                                                                                        raise exception 'ROOM_ACCESS_REQUIRED';
                                                                                                          end if;

                                                                                                            select gift_name, coin_price, diamond_value
                                                                                                              into v_gift_name, v_coin_price, v_diamond_value
                                                                                                                from public.gifts
                                                                                                                  where id = p_gift_id
                                                                                                                      and is_active = true;

                                                                                                                        if not found then
                                                                                                                            raise exception 'GIFT_NOT_AVAILABLE';
                                                                                                                              end if;

                                                                                                                                if v_coin_price is null or v_coin_price < 0
                                                                                                                                     or v_diamond_value is null or v_diamond_value < 0 then
                                                                                                                                         raise exception 'INVALID_GIFT_PRICE';
                                                                                                                                           end if;

                                                                                                                                             if v_coin_price::numeric * p_quantity::numeric > 9223372036854775807
                                                                                                                                                  or v_diamond_value::numeric * p_quantity::numeric > 9223372036854775807 then
                                                                                                                                                      raise exception 'QUANTITY_TOO_LARGE';
                                                                                                                                                        end if;

                                                                                                                                                          v_total_coins := v_coin_price * p_quantity;
                                                                                                                                                            v_total_diamonds := v_diamond_value * p_quantity;

                                                                                                                                                              insert into public.wallets (user_id, coins, diamonds)
                                                                                                                                                                values (v_host, 0, 0)
                                                                                                                                                                  on conflict (user_id) do nothing;

                                                                                                                                                                    perform 1
                                                                                                                                                                      from public.wallets
                                                                                                                                                                        where user_id in (v_sender, v_host)
                                                                                                                                                                          order by user_id
                                                                                                                                                                            for update;

                                                                                                                                                                              select coins
                                                                                                                                                                                into v_sender_coins
                                                                                                                                                                                  from public.wallets
                                                                                                                                                                                    where user_id = v_sender;

                                                                                                                                                                                      if not found then
                                                                                                                                                                                          raise exception 'SENDER_WALLET_NOT_FOUND';
                                                                                                                                                                                            end if;

                                                                                                                                                                                              if v_sender_coins < v_total_coins then
                                                                                                                                                                                                  raise exception 'INSUFFICIENT_COINS';
                                                                                                                                                                                                    end if;

                                                                                                                                                                                                      update public.wallets
                                                                                                                                                                                                        set coins = coins - v_total_coins,
                                                                                                                                                                                                              updated_at = now()
                                                                                                                                                                                                                where user_id = v_sender;

                                                                                                                                                                                                                  update public.wallets
                                                                                                                                                                                                                    set diamonds = diamonds + v_total_diamonds,
                                                                                                                                                                                                                          updated_at = now()
                                                                                                                                                                                                                            where user_id = v_host;

                                                                                                                                                                                                                              insert into public.gift_sends (
                                                                                                                                                                                                                                  sender_id,
                                                                                                                                                                                                                                      receiver_id,
                                                                                                                                                                                                                                          gift_id,
                                                                                                                                                                                                                                              quantity,
                                                                                                                                                                                                                                                  total_coins,
                                                                                                                                                                                                                                                      room_id
                                                                                                                                                                                                                                                        )
                                                                                                                                                                                                                                                          values (
                                                                                                                                                                                                                                                              v_sender,
                                                                                                                                                                                                                                                                  v_host,
                                                                                                                                                                                                                                                                      p_gift_id,
                                                                                                                                                                                                                                                                          p_quantity,
                                                                                                                                                                                                                                                                              v_total_coins,
                                                                                                                                                                                                                                                                                  p_room_id
                                                                                                                                                                                                                                                                                    );

                                                                                                                                                                                                                                                                                      insert into public.wallet_transactions (
                                                                                                                                                                                                                                                                                          user_id,
                                                                                                                                                                                                                                                                                              transaction_type,
                                                                                                                                                                                                                                                                                                  currency,
                                                                                                                                                                                                                                                                                                      amount,
                                                                                                                                                                                                                                                                                                          description
                                                                                                                                                                                                                                                                                                            )
                                                                                                                                                                                                                                                                                                              values
                                                                                                                                                                                                                                                                                                                (
                                                                                                                                                                                                                                                                                                                    v_sender,
                                                                                                                                                                                                                                                                                                                        'gift_sent',
                                                                                                                                                                                                                                                                                                                            'coins',
                                                                                                                                                                                                                                                                                                                                -v_total_coins,
                                                                                                                                                                                                                                                                                                                                    'Sent ' || v_gift_name || ' x' || p_quantity
                                                                                                                                                                                                                                                                                                                                      ),
                                                                                                                                                                                                                                                                                                                                        (
                                                                                                                                                                                                                                                                                                                                            v_host,
                                                                                                                                                                                                                                                                                                                                                'gift_received',
                                                                                                                                                                                                                                                                                                                                                    'diamonds',
                                                                                                                                                                                                                                                                                                                                                        v_total_diamonds,
                                                                                                                                                                                                                                                                                                                                                            'Received ' || v_gift_name || ' x' || p_quantity
                                                                                                                                                                                                                                                                                                                                                              );

                                                                                                                                                                                                                                                                                                                                                                return jsonb_build_object(
                                                                                                                                                                                                                                                                                                                                                                    'success', true,
                                                                                                                                                                                                                                                                                                                                                                        'gift_name', v_gift_name,
                                                                                                                                                                                                                                                                                                                                                                            'quantity', p_quantity,
                                                                                                                                                                                                                                                                                                                                                                                'coins_deducted', v_total_coins,
                                                                                                                                                                                                                                                                                                                                                                                    'diamonds_received', v_total_diamonds,
                                                                                                                                                                                                                                                                                                                                                                                        'receiver_id', v_host
                                                                                                                                                                                                                                                                                                                                                                                          );
                                                                                                                                                                                                                                                                                                                                                                                          end;
                                                                                                                                                                                                                                                                                                                                                                                          $function$
